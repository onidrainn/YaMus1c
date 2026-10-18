# main.py
import os
from flask import Flask, request, jsonify, Response
import requests
from yandex_music import Client

app = Flask(__name__)

_clients = {}

def read_local_token() -> str:
    for path in ("session.txt", os.path.join("Resources", "session.txt")):
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                t = "".join(f.read().split())
                if t:
                    return t
    return ""

def get_token() -> str:
    token = request.headers.get("X-Ya-Token", "").strip()
    if not token:
        token = request.args.get("token", "").strip()
    if not token:
        token = read_local_token()
    return token

def get_client(token: str) -> Client:
    if token not in _clients:
        _clients[token] = Client(token).init()
    return _clients[token]

def resolve_direct_mp3_url(track_id: str, client: Client) -> str:
    infos = client.tracks_download_info(track_id, get_direct_links=True)
    if not infos:
        raise RuntimeError("No download info available for track")
    mp3_infos = [i for i in infos if i.codec == "mp3"] or infos
    best = sorted(mp3_infos, key=lambda x: x.bitrate_in_kbps or 0, reverse=True)[0]
    return best.direct_link or best.get_direct_link()

def format_track(track, host_url: str, token: str) -> dict:
    track_id = str(track.id)
    title = track.title or "Без названия"
    artists = ", ".join(a.name for a in (track.artists or []) if a.name) or "Неизвестен"
    albums = track.albums or []
    album_title = (albums[0].title or "") if albums else ""
    duration_sec = int(track.duration_ms or 0) // 1000

    cover_uri = track.cover_uri or (albums[0].cover_uri if albums and albums[0].cover_uri else "")
    cover_url = ""
    if cover_uri:
        clean_uri = cover_uri.replace("%%", "200x200")
        cover_url = f"{host_url.rstrip('/')}/cover?uri={clean_uri}"

    # Ссылка ведет на эндпоинт генерации свежего потока на лету
    stream_url = f"{host_url.rstrip('/')}/get-stream/{track_id}.mp3"

    return {
        "id": track_id,
        "title": title,
        "artist": artists,
        "album": album_title,
        "duration": duration_sec,
        "cover_url": cover_url,
        "stream_url": stream_url,
    }

@app.route("/", methods=["GET"])
def index():
    token = get_token()
    if not token:
        return jsonify({"status": "running", "token_loaded": False}), 200
    try:
        client = get_client(token)
        uid = client.me.account.uid if client.me and client.me.account else None
        return jsonify({"status": "running", "token_loaded": True, "uid": uid}), 200
    except Exception as e:
        return jsonify({"status": "error", "error": str(e)}), 500

@app.route("/likes", methods=["GET"])
def get_likes():
    token = get_token()
    if not token:
        return jsonify({"error": "Missing token"}), 401
    try:
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
    # Извлекаем ID трека из строки вида "118642431.mp3" или просто "118642431"
    track_id = filename.split(".")[0]
    token = get_token()
    if not token:
        return "Unauthorized", 401
    try:
        client = get_client(token)
        direct_url = resolve_direct_mp3_url(track_id, client)

        req_headers = {}
        if "Range" in request.headers:
            req_headers["Range"] = request.headers["Range"]

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
            upstream.iter_content(chunk_size=32768),
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