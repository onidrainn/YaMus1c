# main.py
import os
import json
import time
import threading
from collections import deque
from datetime import datetime, timezone
from flask import Flask, request, jsonify, Response
import requests
from yandex_music import Client

app = Flask(__name__)

YANDEX_CLIENT_ID = "23cabbbdc6cd418abb4b39c32c41195d"
YANDEX_CLIENT_SECRET = "53bc75238f0c4d08a118e51fe9203300"

AUTH_CACHE_FILE = "auth_state.json"
_clients = {}

# Сессии "Моей Волны" для каждого токена
_wave_sessions = {}
_wave_lock = threading.Lock()

# Кэш прямых ссылок на MP3 и предзагруженных стартовых чанков
_direct_url_cache = {}
_preloaded_chunks = {}
_cache_lock = threading.Lock()

DIRECT_URL_TTL = 600  # 10 минут
PRELOAD_BYTES = 262144  # 256 КБ стартового буфера в RAM прокси


def save_auth_state(token: str, account_name: str = ""):
    try:
        with open(AUTH_CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump({"token": token, "account_name": account_name}, f, ensure_ascii=False)
    except Exception:
        pass


def load_cached_token() -> str:
    if os.path.exists(AUTH_CACHE_FILE):
        try:
            with open(AUTH_CACHE_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("token", "").strip()
        except Exception:
            pass
    return ""


def get_token() -> str:
    token = request.headers.get("X-Ya-Token", "").strip()
    if not token:
        token = request.args.get("token", "").strip()
    if not token:
        token = load_cached_token()
    return token


def get_client(token: str) -> Client:
    if token not in _clients:
        _clients[token] = Client(token).init()
    return _clients[token]


def fetch_account_name(token: str) -> str:
    try:
        r = requests.get(
            "https://login.yandex.ru/info?format=json",
            headers={"Authorization": f"OAuth {token}"},
            timeout=10,
        )
        if r.status_code == 200:
            info = r.json()
            name = (
                info.get("display_name")
                or info.get("real_name")
                or info.get("login")
                or info.get("default_email")
            )
            if name:
                return str(name)
    except Exception:
        pass

    try:
        client = get_client(token)
        if client.me and client.me.account:
            acc = client.me.account
            name = acc.display_name or acc.full_name or acc.login or str(acc.uid or "")
            if name:
                return str(name)
    except Exception:
        pass

    return "Пользователь Яндекса"


def resolve_direct_mp3_url(track_id: str, client: Client) -> str:
    now = time.time()
    with _cache_lock:
        cached = _direct_url_cache.get(track_id)
        if cached and (now - cached["ts"] < DIRECT_URL_TTL):
            return cached["url"]

    infos = client.tracks_download_info(track_id, get_direct_links=True)
    if not infos:
        raise RuntimeError("No download info available for track")
    mp3_infos = [i for i in infos if i.codec == "mp3"] or infos
    best = sorted(mp3_infos, key=lambda x: x.bitrate_in_kbps or 0, reverse=True)[0]
    url = best.direct_link or best.get_direct_link()

    with _cache_lock:
        if len(_direct_url_cache) > 200:
            _direct_url_cache.clear()
        _direct_url_cache[track_id] = {"url": url, "ts": now}

    return url


def preload_track_async(track_id: str, token: str):
    def _worker():
        try:
            client = get_client(token)
            direct_url = resolve_direct_mp3_url(track_id, client)
            with _cache_lock:
                if track_id in _preloaded_chunks:
                    return
            r = requests.get(
                direct_url,
                headers={"Range": f"bytes=0-{PRELOAD_BYTES - 1}"},
                timeout=10,
            )
            if r.status_code in (200, 206) and r.content:
                with _cache_lock:
                    if len(_preloaded_chunks) > 30:
                        _preloaded_chunks.clear()
                    _preloaded_chunks[track_id] = {
                        "data": r.content,
                        "ts": time.time(),
                    }
        except Exception:
            pass

    threading.Thread(target=_worker, daemon=True).start()


def format_track(track, host_url: str, token: str) -> dict:
    track_id = str(track.id)
    title = track.title or "Без названия"
    artists = ", ".join(a.name for a in (track.artists or []) if a.name) or "Неизвестен"
    albums = track.albums or []
    album_title = (albums[0].title or "") if albums else ""
    album_id = str(albums[0].id) if (albums and getattr(albums[0], "id", None)) else ""
    full_rotor_id = f"{track_id}:{album_id}" if album_id else track_id
    duration_sec = int(track.duration_ms or 0) // 1000

    cover_uri = track.cover_uri or (albums[0].cover_uri if albums and albums[0].cover_uri else "")
    cover_url = ""
    if cover_uri:
        clean_uri = cover_uri.replace("%%", "1000x1000")
        cover_url = f"{host_url.rstrip('/')}/cover?uri={clean_uri}"

    stream_url = f"{host_url.rstrip('/')}/get-stream/{track_id}.mp3"

    return {
        "id": track_id,
        "rotor_id": full_rotor_id,
        "title": title,
        "artist": artists,
        "album": album_title,
        "duration": duration_sec,
        "cover_url": cover_url,
        "stream_url": stream_url,
    }


def _get_wave_session(token: str) -> dict:
    with _wave_lock:
        if token not in _wave_sessions:
            _wave_sessions[token] = {
                "batch_id": None,
                "seen_ids": deque(maxlen=400),
                "last_batch_tracks": [],  # список кортежей (track_id, full_rotor_id, duration_sec)
                "radio_started": False,
            }
        return _wave_sessions[token]


def _send_rotor_feedback(client: Client, feedback_type: str, batch_id: str = None, track_id: str = None, played_sec: float = 0.0):
    now_iso = datetime.now(timezone.utc).isoformat()
    station = "user:onyourwave"
    from_str = "mobile-home-rup_main-user-onyourwave-default"
    try:
        if feedback_type == "radioStarted":
            client.rotor_station_feedback_radio_started(station=station, from_=from_str, timestamp=now_iso)
        elif feedback_type == "trackStarted" and track_id:
            client.rotor_station_feedback_track_started(station=station, track_id=track_id, batch_id=batch_id, timestamp=now_iso)
        elif feedback_type == "trackFinished" and track_id:
            client.rotor_station_feedback_track_finished(
                station=station,
                track_id=track_id,
                total_played_seconds=max(1.0, float(played_sec)),
                batch_id=batch_id,
                timestamp=now_iso,
            )
        elif feedback_type == "skip" and track_id:
            client.rotor_station_feedback_skip(
                station=station,
                track_id=track_id,
                total_played_seconds=max(1.0, float(played_sec)),
                batch_id=batch_id,
                timestamp=now_iso,
            )
        else:
            client.rotor_station_feedback(
                station=station,
                type_=feedback_type,
                timestamp=now_iso,
                from_=from_str,
                batch_id=batch_id,
                track_id=track_id,
                total_played_seconds=played_sec if played_sec > 0 else None,
            )
    except Exception:
        pass


@app.route("/auth/device/start", methods=["POST", "GET"])
def auth_device_start():
    try:
        r = requests.post(
            "https://oauth.yandex.ru/device/code",
            data={"client_id": YANDEX_CLIENT_ID},
            timeout=15,
        )
        r.raise_for_status()
        data = r.json()
        return jsonify({
            "device_code": data.get("device_code", ""),
            "user_code": data.get("user_code", ""),
            "verification_url": data.get("verification_url", "https://ya.ru/device"),
            "interval": data.get("interval", 5),
            "expires_in": data.get("expires_in", 300),
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/auth/device/poll", methods=["POST"])
def auth_device_poll():
    body = request.get_json(silent=True) or {}
    device_code = body.get("device_code", "").strip()
    if not device_code:
        return jsonify({"error": "Missing device_code"}), 400

    try:
        r = requests.post(
            "https://oauth.yandex.ru/token",
            data={
                "grant_type": "device_code",
                "code": device_code,
                "client_id": YANDEX_CLIENT_ID,
                "client_secret": YANDEX_CLIENT_SECRET,
            },
            timeout=15,
        )
        data = r.json()

        if "access_token" in data:
            token = data["access_token"]
            account_name = fetch_account_name(token)
            save_auth_state(token, account_name)
            return jsonify({
                "status": "ok",
                "access_token": token,
                "account_name": account_name,
            })

        err_code = data.get("error", "authorization_pending")
        if err_code in ("authorization_pending", "slow_down"):
            return jsonify({"status": "pending", "error": err_code}), 200

        return jsonify({"status": "error", "error": data.get("error_description") or err_code}), 400
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500


@app.route("/account", methods=["GET"])
def get_account():
    token = get_token()
    if not token:
        return jsonify({"error": "Unauthorized"}), 401
    account_name = fetch_account_name(token)
    save_auth_state(token, account_name)
    return jsonify({"account_name": account_name})


@app.route("/rotor/wave", methods=["GET"])
def get_my_wave():
    token = get_token()
    if not token:
        return jsonify({"error": "Missing token"}), 401
    try:
        client = get_client(token)
        session = _get_wave_session(token)
        reset_flag = request.args.get("reset", "0") == "1"
        queue_arg = request.args.get("queue", "").strip()

        if reset_flag or not session["radio_started"]:
            _send_rotor_feedback(client, "radioStarted")
            session["radio_started"] = True

        host = request.host_url
        collected_tracks = []

        # Делаем до 4 запросов к Ротору, если Яндекс вернул уже проигранные треки
        for _ in range(4):
            prev_batch_id = session["batch_id"]
            prev_tracks = session["last_batch_tracks"]

            queue_param = None
            if prev_tracks:
                # Отправляем фидбек по предыдущей пачке, чтобы Яндекс сдвинул волну вперёд
                for _, full_id, dur in prev_tracks:
                    _send_rotor_feedback(client, "trackStarted", batch_id=prev_batch_id, track_id=full_id)
                    _send_rotor_feedback(client, "trackFinished", batch_id=prev_batch_id, track_id=full_id, played_sec=max(30, dur))
                queue_param = prev_tracks[-1][1]
            elif queue_arg:
                queue_param = queue_arg

            station_result = client.rotor_station_tracks("user:onyourwave", settings2=True, queue=queue_param)
            if not station_result or not station_result.sequence:
                break

            new_batch_id = getattr(station_result, "batch_id", None)
            session["batch_id"] = new_batch_id

            current_batch_meta = []
            for seq_item in station_result.sequence:
                t = getattr(seq_item, "track", None)
                if not t or not getattr(t, "id", None):
                    continue
                formatted = format_track(t, host, token)
                tid = formatted["id"]
                rotor_id = formatted["rotor_id"]
                dur = formatted["duration"] or 120
                current_batch_meta.append((tid, rotor_id, dur))

                if tid not in session["seen_ids"]:
                    session["seen_ids"].append(tid)
                    collected_tracks.append(formatted)

            session["last_batch_tracks"] = current_batch_meta

            # Сообщаем Ротору, что первый трек новой пачки начал играть
            if current_batch_meta:
                _send_rotor_feedback(client, "trackStarted", batch_id=new_batch_id, track_id=current_batch_meta[0][1])

            if len(collected_tracks) >= 5:
                break

        # Если вдруг все пачки совпали, очищаем историю просмотренных и отдаём текущую пачку
        if not collected_tracks and session["last_batch_tracks"]:
            session["seen_ids"].clear()
            station_result = client.rotor_station_tracks("user:onyourwave", settings2=True, queue=None)
            if station_result and station_result.sequence:
                for seq_item in station_result.sequence:
                    t = getattr(seq_item, "track", None)
                    if t and getattr(t, "id", None):
                        formatted = format_track(t, host, token)
                        session["seen_ids"].append(formatted["id"])
                        collected_tracks.append(formatted)

        # Предзагружаем первый трек в фоне на сервере для мгновенного старта
        if collected_tracks:
            preload_track_async(collected_tracks[0]["id"], token)

        return jsonify({
            "tracks": collected_tracks,
            "batch_id": session["batch_id"] or "",
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/rotor/feedback", methods=["POST"])
def rotor_feedback():
    token = get_token()
    if not token:
        return jsonify({"error": "Missing token"}), 401
    data = request.get_json(silent=True) or {}
    fb_type = data.get("type", "trackFinished")
    track_id = str(data.get("track_id", "")).strip()
    played_sec = float(data.get("played_seconds", 0.0) or 0.0)

    if not track_id:
        return jsonify({"status": "ignored"})

    try:
        client = get_client(token)
        session = _get_wave_session(token)
        batch_id = session.get("batch_id")

        # Ищем полный rotor_id (track_id:album_id), если он есть в последней пачке
        full_id = track_id
        for tid, rid, _ in session.get("last_batch_tracks", []):
            if tid == track_id:
                full_id = rid
                break

        _send_rotor_feedback(client, fb_type, batch_id=batch_id, track_id=full_id, played_sec=played_sec)
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/preload/<track_id>", methods=["POST", "GET"])
def preload_track_endpoint(track_id):
    token = get_token()
    if not token or not track_id:
        return jsonify({"status": "ignored"}), 200
    clean_id = track_id.split(".")[0]
    preload_track_async(clean_id, token)
    return jsonify({"status": "preloading", "track_id": clean_id}), 200


@app.route("/likes", methods=["GET"])
def get_likes():
    token = get_token()
    if not token:
        return jsonify({"error": "Missing token"}), 401
    try:
        save_auth_state(token)
        client = get_client(token)
        likes_list = client.users_likes_tracks()
        if not likes_list or not likes_list.tracks:
            return jsonify({"tracks": []})

        short_tracks = likes_list.tracks[:200]
        track_ids = [
            f"{t.id}:{t.album_id}" if t.album_id else str(t.id)
            for t in short_tracks
        ]
        full_tracks = client.tracks(track_ids)
        host = request.host_url
        result = [format_track(t, host, token) for t in full_tracks if t and t.id]
        return jsonify({"tracks": result})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/likes/add", methods=["POST"])
def add_like():
    token = get_token()
    data = request.get_json(silent=True) or {}
    track_ids = [str(tid) for tid in data.get("track_ids", [])]
    if not token or not track_ids:
        return jsonify({"error": "Missing token or track_ids"}), 400
    try:
        client = get_client(token)
        client.users_likes_tracks_add(track_ids)
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/likes/remove", methods=["POST"])
def remove_likes():
    token = get_token()
    data = request.get_json(silent=True) or {}
    track_ids = [str(tid) for tid in data.get("track_ids", [])]
    if not token or not track_ids:
        return jsonify({"error": "Missing token or track_ids"}), 400
    try:
        client = get_client(token)
        client.users_likes_tracks_remove(track_ids)
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/search", methods=["GET"])
def search():
    token = get_token()
    query = request.args.get("q", "").strip()
    if not token or not query:
        return jsonify({"tracks": [], "artists": [], "albums": []})
    try:
        client = get_client(token)
        res = client.search(query, nocorrect=False, type_="all", page=0)
        host = request.host_url

        raw_tracks = res.tracks.results if (res and res.tracks and res.tracks.results) else []
        tracks = [format_track(t, host, token) for t in raw_tracks]

        raw_artists = res.artists.results if (res and res.artists and res.artists.results) else []
        artists = [{"id": str(a.id), "name": a.name or "", "genres": ", ".join((a.genres or [])[:2])} for a in raw_artists]

        raw_albums = res.albums.results if (res and res.albums and res.albums.results) else []
        albums = [{"id": str(al.id), "title": al.title or "", "artist": ", ".join(ar.name for ar in (al.artists or []) if ar.name), "year": str(al.year or "")} for al in raw_albums]

        return jsonify({"tracks": tracks, "artists": artists, "albums": albums})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/get-stream/<path:filename>", methods=["GET", "HEAD"])
def get_stream(filename):
    track_id = filename.split(".")[0]
    token = get_token()
    if not token:
        return "Unauthorized", 401
    try:
        client = get_client(token)
        direct_url = resolve_direct_mp3_url(track_id, client)

        req_headers = {}
        range_header = request.headers.get("Range")
        if range_header:
            req_headers["Range"] = range_header

        if request.method == "HEAD":
            head_resp = requests.head(direct_url, headers=req_headers, timeout=10)
            resp = Response(status=head_resp.status_code)
            for h in ("Content-Length", "Content-Range", "Accept-Ranges"):
                if h in head_resp.headers:
                    resp.headers[h] = head_resp.headers[h]
            resp.headers["Accept-Ranges"] = "bytes"
            resp.headers["Content-Type"] = "audio/mpeg"
            resp.headers["Content-Disposition"] = f"inline; filename={track_id}.mp3"
            return resp

        upstream = requests.get(direct_url, headers=req_headers, stream=True, timeout=30)

        resp_headers = {
            "Content-Type": "audio/mpeg",
            "Accept-Ranges": "bytes",
            "Content-Disposition": f"inline; filename={track_id}.mp3"
        }
        for h in ("Content-Length", "Content-Range"):
            if h in upstream.headers:
                resp_headers[h] = upstream.headers[h]

        return Response(
            upstream.iter_content(chunk_size=16384),
            status=upstream.status_code,
            headers=resp_headers,
        )
    except Exception as e:
        return str(e), 500


@app.route("/cover", methods=["GET"])
def proxy_cover():
    uri = request.args.get("uri", "").strip()
    if not uri:
        return "Missing uri", 400
    url = f"https://{uri}" if not uri.startswith("http") else uri
    try:
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        return Response(r.content, content_type=r.headers.get("Content-Type", "image/jpeg"))
    except Exception as e:
        return str(e), 404


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=6500, threaded=True)