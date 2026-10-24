#import "YMControllers.h"

NSString *const YMThemeDidChangeNotification = @"YMThemeDidChangeNotification";
static NSString *const kYMAccentIOS6DefaultsKey = @"YMSelectedAccentIOS6";
static NSString *const kYMIconSetDefaultsKey = @"YMSelectedIconSetType";
static NSString *const kYMSelectedIconDefaultsKey = @"YMSelectedAppIconIndex";

extern int system(const char *command);

#pragma mark - UIImage Tinting Category

@implementation UIImage (YMTint)
- (UIImage *)ym_tintedImageWithColor:(UIColor *)color {
    if (!color) return self;
    CGSize size = self.size;
    if (size.width <= 0 || size.height <= 0) return self;
    UIGraphicsBeginImageContextWithOptions(size, NO, self.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    CGContextClipToMask(context, rect, self.CGImage);
    [color setFill];
    CGContextFillRect(context, rect);
    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return coloredImg;
}
@end

#pragma mark - YMThemeManager (Чистый стоковый UIKit)

@implementation YMThemeManager

+ (instancetype)shared {
    static YMThemeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YMThemeManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        if ([defs objectForKey:kYMAccentIOS6DefaultsKey] != nil) {
            _currentAccentColor = (YMAccentColor)[defs integerForKey:kYMAccentIOS6DefaultsKey];
        } else {
            _currentAccentColor = YMAccentColorBlue;
        }
        _currentIconSet = (YMIconSetType)[defs integerForKey:kYMIconSetDefaultsKey];
    }
    return self;
}

- (void)setCurrentAccentColor:(YMAccentColor)currentAccentColor {
    if (_currentAccentColor == currentAccentColor) return;
    _currentAccentColor = currentAccentColor;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:currentAccentColor forKey:kYMAccentIOS6DefaultsKey];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMThemeDidChangeNotification object:nil];
}

- (void)setCurrentIconSet:(YMIconSetType)currentIconSet {
    if (_currentIconSet == currentIconSet) return;
    _currentIconSet = currentIconSet;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setInteger:currentIconSet forKey:kYMIconSetDefaultsKey];
    [defs synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:YMThemeDidChangeNotification object:nil];
}

- (NSString *)accentNameForColor:(YMAccentColor)accent {
    switch (accent) {
        case YMAccentColorRed:      return @"Красный";
        case YMAccentColorOrange:   return @"Оранжевый";
        case YMAccentColorYellow:   return @"Жёлтый";
        case YMAccentColorGreen:    return @"Зелёный";
        case YMAccentColorBlue:     return @"Синий (iOS 6)";
        case YMAccentColorLilac:    return @"Лиловый";
        case YMAccentColorPink:     return @"Розовый";
        case YMAccentColorGraphite: return @"Графит";
        default:                    return @"Синий (iOS 6)";
    }
}

- (UIColor *)swatchColorForAccent:(YMAccentColor)accent {
    switch (accent) {
        case YMAccentColorRed:      return [UIColor colorWithRed:0.88 green:0.20 blue:0.22 alpha:1.0];
        case YMAccentColorOrange:   return [UIColor colorWithRed:0.92 green:0.48 blue:0.12 alpha:1.0];
        case YMAccentColorYellow:   return [UIColor colorWithRed:0.88 green:0.68 blue:0.08 alpha:1.0];
        case YMAccentColorGreen:    return [UIColor colorWithRed:0.20 green:0.68 blue:0.32 alpha:1.0];
        case YMAccentColorBlue:     return [UIColor colorWithRed:0.20 green:0.52 blue:0.92 alpha:1.0];
        case YMAccentColorLilac:    return [UIColor colorWithRed:0.60 green:0.40 blue:0.88 alpha:1.0];
        case YMAccentColorPink:     return [UIColor colorWithRed:0.88 green:0.30 blue:0.60 alpha:1.0];
        case YMAccentColorGraphite: return [UIColor colorWithRed:0.48 green:0.52 blue:0.58 alpha:1.0];
        default:                    return [UIColor colorWithRed:0.20 green:0.52 blue:0.92 alpha:1.0];
    }
}

- (UIColor *)playerAccentColor {
    return [self swatchColorForAccent:self.currentAccentColor];
}

- (UIImage *)swatchImageForAccent:(YMAccentColor)accent {
    CGSize size = CGSizeMake(22.0, 22.0);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(1.0, 1.0, 20.0, 20.0)];
    [[self swatchColorForAccent:accent] setFill];
    [circle fill];
    [[UIColor colorWithWhite:0.0 alpha:0.25] setStroke];
    circle.lineWidth = 1.0;
    [circle stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (NSString *)currentAppearanceSummary {
    NSString *iconsName = (self.currentIconSet == YMIconSetTypeVector) ? @"Векторные" : @"Основные";
    return [NSString stringWithFormat:@"%@ • %@", [self accentNameForColor:self.currentAccentColor], iconsName];
}

- (UIColor *)accentColor {
    switch (self.currentAccentColor) {
        case YMAccentColorRed:      return [UIColor colorWithRed:0.75 green:0.16 blue:0.18 alpha:1.0];
        case YMAccentColorOrange:   return [UIColor colorWithRed:0.85 green:0.42 blue:0.10 alpha:1.0];
        case YMAccentColorYellow:   return [UIColor colorWithRed:0.78 green:0.58 blue:0.06 alpha:1.0];
        case YMAccentColorGreen:    return [UIColor colorWithRed:0.15 green:0.55 blue:0.25 alpha:1.0];
        case YMAccentColorBlue:     return nil; // nil включает стандартный системный синий цвет UIKit в iOS 6
        case YMAccentColorLilac:    return [UIColor colorWithRed:0.48 green:0.32 blue:0.74 alpha:1.0];
        case YMAccentColorPink:     return [UIColor colorWithRed:0.76 green:0.24 blue:0.50 alpha:1.0];
        case YMAccentColorGraphite: return [UIColor colorWithRed:0.35 green:0.38 blue:0.43 alpha:1.0];
        default:                    return nil;
    }
}

#pragma mark - Оформление обложки и зеркального отражения в стиле iOS 6 «Музыка»

- (UIImage *)defaultAlbumPlaceholderWithSize:(CGSize)size {
    if (size.width <= 0 || size.height <= 0) size = CGSizeMake(240.0, 240.0);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();

    CGFloat comps[] = {
        0.20, 0.21, 0.24, 1.0,
        0.11, 0.12, 0.14, 1.0,
        0.06, 0.06, 0.08, 1.0
    };
    CGFloat locs[] = {0.0, 0.52, 1.0};
    CGGradientRef grad = CGGradientCreateWithColorComponents(space, comps, locs, 3);
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(grad);
    CGColorSpaceRelease(space);

    [[UIColor colorWithWhite:1.0 alpha:0.04] setStroke];
    for (int i = 1; i <= 3; i++) {
        CGFloat r = (size.width * 0.14) * i;
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectMake((size.width - r * 2.0) / 2.0, (size.height - r * 2.0) / 2.0, r * 2.0, r * 2.0)];
        ring.lineWidth = 1.0;
        [ring stroke];
    }

    CGSize noteSize = CGSizeMake(size.width * 0.36, size.height * 0.36);
    UIImage *noteImg = [self vectorMusicNoteWithColor:[UIColor colorWithWhite:1.0 alpha:0.24] size:noteSize];
    if (noteImg) {
        [noteImg drawInRect:CGRectMake((size.width - noteSize.width) / 2.0, (size.height - noteSize.height) / 2.0, noteSize.width, noteSize.height)];
    }

    [[UIColor colorWithWhite:1.0 alpha:0.18] setStroke];
    UIBezierPath *border = [UIBezierPath bezierPathWithRect:CGRectMake(0.5, 0.5, size.width - 1.0, size.height - 1.0)];
    border.lineWidth = 1.0;
    [border stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)framedAlbumImageFromImage:(UIImage *)rawImage side:(CGFloat)side {
    if (side <= 0) side = 240.0;
    CGSize targetSize = CGSizeMake(side, side);
    if (!rawImage) {
        return [self defaultAlbumPlaceholderWithSize:targetSize];
    }

    UIGraphicsBeginImageContextWithOptions(targetSize, YES, 0.0);
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0, 0, side, side));

    CGSize imgSize = rawImage.size;
    if (imgSize.width > 0 && imgSize.height > 0) {
        CGFloat scale = MAX(side / imgSize.width, side / imgSize.height);
        CGFloat drawW = imgSize.width * scale;
        CGFloat drawH = imgSize.height * scale;
        CGRect drawRect = CGRectMake((side - drawW) / 2.0, (side - drawH) / 2.0, drawW, drawH);
        [rawImage drawInRect:drawRect];
    } else {
        [rawImage drawInRect:CGRectMake(0, 0, side, side)];
    }

    [[UIColor colorWithWhite:1.0 alpha:0.18] setStroke];
    UIBezierPath *framePath = [UIBezierPath bezierPathWithRect:CGRectMake(0.5, 0.5, side - 1.0, side - 1.0)];
    framePath.lineWidth = 1.0;
    [framePath stroke];

    UIImage *framed = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return framed;
}

- (UIImage *)reflectionImageFromAlbumImage:(UIImage *)albumImage side:(CGFloat)side reflectionHeight:(CGFloat)reflH {
    if (!albumImage || side <= 0 || reflH <= 0) return nil;
    CGSize reflSize = CGSizeMake(side, reflH);

    CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
    CGContextRef maskCtx = CGBitmapContextCreate(NULL, (size_t)side, (size_t)reflH, 8, (size_t)side, graySpace, kCGImageAlphaNone);
    if (!maskCtx) {
        CGColorSpaceRelease(graySpace);
        return nil;
    }

    CGFloat maskComps[] = {0.36, 1.0, 0.0, 1.0};
    CGFloat maskLocs[] = {0.0, 1.0};
    CGGradientRef maskGrad = CGGradientCreateWithColorComponents(graySpace, maskComps, maskLocs, 2);
    CGContextDrawLinearGradient(maskCtx, maskGrad, CGPointMake(0, reflH), CGPointMake(0, 0), 0);
    CGImageRef alphaMask = CGBitmapContextCreateImage(maskCtx);

    CGGradientRelease(maskGrad);
    CGContextRelease(maskCtx);
    CGColorSpaceRelease(graySpace);

    UIGraphicsBeginImageContextWithOptions(reflSize, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClipToMask(ctx, CGRectMake(0, 0, side, reflH), alphaMask);
    CGImageRelease(alphaMask);

    CGContextTranslateCTM(ctx, 0.0, side);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    [albumImage drawInRect:CGRectMake(0, 0, side, side)];

    UIImage *reflection = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return reflection;
}

#pragma mark - Векторная отрисовка иконок

- (UIImage *)vectorHeartImageFilled:(BOOL)filled color:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setFill];
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(w * 0.50, h * 0.84)];
    [path addCurveToPoint:CGPointMake(w * 0.09, h * 0.39)
            controlPoint1:CGPointMake(w * 0.30, h * 0.70)
            controlPoint2:CGPointMake(w * 0.09, h * 0.56)];
    [path addCurveToPoint:CGPointMake(w * 0.29, h * 0.16)
            controlPoint1:CGPointMake(w * 0.09, h * 0.24)
            controlPoint2:CGPointMake(w * 0.18, h * 0.16)];
    [path addCurveToPoint:CGPointMake(w * 0.50, h * 0.29)
            controlPoint1:CGPointMake(w * 0.38, h * 0.16)
            controlPoint2:CGPointMake(w * 0.45, h * 0.21)];
    [path addCurveToPoint:CGPointMake(w * 0.71, h * 0.16)
            controlPoint1:CGPointMake(w * 0.55, h * 0.21)
            controlPoint2:CGPointMake(w * 0.62, h * 0.16)];
    [path addCurveToPoint:CGPointMake(w * 0.91, h * 0.39)
            controlPoint1:CGPointMake(w * 0.82, h * 0.16)
            controlPoint2:CGPointMake(w * 0.91, h * 0.24)];
    [path addCurveToPoint:CGPointMake(w * 0.50, h * 0.84)
            controlPoint1:CGPointMake(w * 0.91, h * 0.56)
            controlPoint2:CGPointMake(w * 0.70, h * 0.70)];
    [path closePath];

    if (filled) {
        [path fill];
    } else {
        path.lineWidth = MAX(2.0, w * 0.105);
        path.lineJoinStyle = kCGLineJoinRound;
        path.lineCapStyle = kCGLineCapRound;
        [path stroke];
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorMusicNoteWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];
    [color setFill];

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat strokeW = MAX(2.2, w * 0.105);

    UIBezierPath *head = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(w * 0.18, h * 0.56, w * 0.36, h * 0.28)];
    head.lineWidth = strokeW;
    [head stroke];

    CGFloat stemX = w * 0.54;
    UIBezierPath *stem = [UIBezierPath bezierPath];
    [stem moveToPoint:CGPointMake(stemX, h * 0.68)];
    [stem addLineToPoint:CGPointMake(stemX, h * 0.16)];
    stem.lineWidth = strokeW;
    stem.lineCapStyle = kCGLineCapRound;
    [stem stroke];

    UIBezierPath *flag = [UIBezierPath bezierPath];
    [flag moveToPoint:CGPointMake(stemX, h * 0.16)];
    [flag addCurveToPoint:CGPointMake(w * 0.82, h * 0.44)
            controlPoint1:CGPointMake(w * 0.72, h * 0.18)
            controlPoint2:CGPointMake(w * 0.84, h * 0.30)];
    flag.lineWidth = strokeW;
    flag.lineCapStyle = kCGLineCapRound;
    [flag stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorSearchIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(w * 0.12, h * 0.12, w * 0.54, h * 0.54)];
    lens.lineWidth = MAX(2.3, w * 0.115);
    [lens stroke];

    UIBezierPath *neck = [UIBezierPath bezierPath];
    [neck moveToPoint:CGPointMake(w * 0.58, h * 0.58)];
    [neck addLineToPoint:CGPointMake(w * 0.66, h * 0.66)];
    neck.lineWidth = MAX(1.8, w * 0.08);
    neck.lineCapStyle = kCGLineCapRound;
    [neck stroke];

    UIBezierPath *handle = [UIBezierPath bezierPath];
    [handle moveToPoint:CGPointMake(w * 0.65, h * 0.65)];
    [handle addLineToPoint:CGPointMake(w * 0.86, h * 0.86)];
    handle.lineWidth = MAX(3.4, w * 0.165);
    handle.lineCapStyle = kCGLineCapRound;
    [handle stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorDownloadsIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *arrow = [UIBezierPath bezierPath];
    [arrow moveToPoint:CGPointMake(w * 0.40, h * 0.12)];
    [arrow addLineToPoint:CGPointMake(w * 0.60, h * 0.12)];
    [arrow addLineToPoint:CGPointMake(w * 0.60, h * 0.43)];
    [arrow addLineToPoint:CGPointMake(w * 0.77, h * 0.43)];
    [arrow addLineToPoint:CGPointMake(w * 0.50, h * 0.71)];
    [arrow addLineToPoint:CGPointMake(w * 0.23, h * 0.43)];
    [arrow addLineToPoint:CGPointMake(w * 0.40, h * 0.43)];
    [arrow closePath];

    arrow.lineWidth = MAX(2.0, w * 0.095);
    arrow.lineJoinStyle = kCGLineJoinRound;
    arrow.lineCapStyle = kCGLineCapRound;
    [arrow stroke];

    UIBezierPath *bar = [UIBezierPath bezierPath];
    [bar moveToPoint:CGPointMake(w * 0.14, h * 0.86)];
    [bar addLineToPoint:CGPointMake(w * 0.86, h * 0.86)];
    bar.lineWidth = MAX(2.4, w * 0.115);
    bar.lineCapStyle = kCGLineCapRound;
    [bar stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorSettingsIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat cx = w * 0.50;
    CGFloat cy = h * 0.50;
    CGFloat rOuter = MIN(w, h) * 0.43;
    CGFloat rRoot = MIN(w, h) * 0.31;
    NSInteger teeth = 6;

    UIBezierPath *gear = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < teeth; i++) {
        CGFloat centerAngle = -M_PI_2 + i * (2.0 * M_PI / teeth);
        CGFloat halfTooth = 0.17;
        CGFloat halfFlank = 0.23;
        CGFloat nextStartAngle = -M_PI_2 + (i + 1) * (2.0 * M_PI / teeth) - halfFlank;

        CGPoint p1 = CGPointMake(cx + rRoot * cosf(centerAngle - halfFlank), cy + rRoot * sinf(centerAngle - halfFlank));
        CGPoint p2 = CGPointMake(cx + rOuter * cosf(centerAngle - halfTooth), cy + rOuter * sinf(centerAngle - halfTooth));
        CGPoint p3 = CGPointMake(cx + rOuter * cosf(centerAngle + halfTooth), cy + rOuter * sinf(centerAngle + halfTooth));
        CGPoint p4 = CGPointMake(cx + rRoot * cosf(centerAngle + halfFlank), cy + rRoot * sinf(centerAngle + halfFlank));

        if (i == 0) {
            [gear moveToPoint:p1];
        } else {
            [gear addLineToPoint:p1];
        }
        [gear addLineToPoint:p2];
        [gear addArcWithCenter:CGPointMake(cx, cy) radius:rOuter startAngle:(centerAngle - halfTooth) endAngle:(centerAngle + halfTooth) clockwise:YES];
        [gear addLineToPoint:p3];
        [gear addLineToPoint:p4];
        [gear addArcWithCenter:CGPointMake(cx, cy) radius:rRoot startAngle:(centerAngle + halfFlank) endAngle:nextStartAngle clockwise:YES];
    }
    [gear closePath];
    gear.lineWidth = MAX(1.9, w * 0.09);
    gear.lineJoinStyle = kCGLineJoinRound;
    [gear stroke];

    CGFloat innerR = MIN(w, h) * 0.145;
    UIBezierPath *innerRing = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - innerR, cy - innerR, innerR * 2.0, innerR * 2.0)];
    innerRing.lineWidth = MAX(2.0, w * 0.095);
    [innerRing stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorPlayIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setFill];
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *tri = [UIBezierPath bezierPath];
    [tri moveToPoint:CGPointMake(w * 0.20, h * 0.14)];
    [tri addLineToPoint:CGPointMake(w * 0.86, h * 0.50)];
    [tri addLineToPoint:CGPointMake(w * 0.20, h * 0.86)];
    [tri closePath];
    tri.lineWidth = 1.6;
    tri.lineJoinStyle = kCGLineJoinRound;
    [tri fill];
    [tri stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorPauseIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setFill];

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat barW = w * 0.21;
    CGFloat barH = h * 0.72;
    CGFloat y = (h - barH) / 2.0;

    UIBezierPath *leftBar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w * 0.20, y, barW, barH) cornerRadius:2.2];
    UIBezierPath *rightBar = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(w * 0.59, y, barW, barH) cornerRadius:2.2];
    [leftBar fill];
    [rightBar fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorPrevIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setFill];
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *t1 = [UIBezierPath bezierPath];
    [t1 moveToPoint:CGPointMake(w * 0.08, h * 0.50)];
    [t1 addLineToPoint:CGPointMake(w * 0.50, h * 0.19)];
    [t1 addLineToPoint:CGPointMake(w * 0.50, h * 0.81)];
    [t1 closePath];

    UIBezierPath *t2 = [UIBezierPath bezierPath];
    [t2 moveToPoint:CGPointMake(w * 0.48, h * 0.50)];
    [t2 addLineToPoint:CGPointMake(w * 0.90, h * 0.19)];
    [t2 addLineToPoint:CGPointMake(w * 0.90, h * 0.81)];
    [t2 closePath];

    t1.lineWidth = 1.2;
    t1.lineJoinStyle = kCGLineJoinRound;
    t2.lineWidth = 1.2;
    t2.lineJoinStyle = kCGLineJoinRound;

    [t1 fill];
    [t1 stroke];
    [t2 fill];
    [t2 stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorNextIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setFill];
    [color setStroke];

    CGFloat w = size.width;
    CGFloat h = size.height;

    UIBezierPath *t1 = [UIBezierPath bezierPath];
    [t1 moveToPoint:CGPointMake(w * 0.10, h * 0.19)];
    [t1 addLineToPoint:CGPointMake(w * 0.52, h * 0.50)];
    [t1 addLineToPoint:CGPointMake(w * 0.10, h * 0.81)];
    [t1 closePath];

    UIBezierPath *t2 = [UIBezierPath bezierPath];
    [t2 moveToPoint:CGPointMake(w * 0.50, h * 0.19)];
    [t2 addLineToPoint:CGPointMake(w * 0.92, h * 0.50)];
    [t2 addLineToPoint:CGPointMake(w * 0.50, h * 0.81)];
    [t2 closePath];

    t1.lineWidth = 1.2;
    t1.lineJoinStyle = kCGLineJoinRound;
    t2.lineWidth = 1.2;
    t2.lineJoinStyle = kCGLineJoinRound;

    [t1 fill];
    [t1 stroke];
    [t2 fill];
    [t2 stroke];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorShuffleIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];
    [color setFill];

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat lineW = MAX(1.8, h * 0.095);

    UIBezierPath *p1 = [UIBezierPath bezierPath];
    [p1 moveToPoint:CGPointMake(w * 0.08, h * 0.31)];
    [p1 addLineToPoint:CGPointMake(w * 0.20, h * 0.31)];
    [p1 addCurveToPoint:CGPointMake(w * 0.58, h * 0.69)
          controlPoint1:CGPointMake(w * 0.38, h * 0.31)
          controlPoint2:CGPointMake(w * 0.40, h * 0.69)];
    [p1 addLineToPoint:CGPointMake(w * 0.72, h * 0.69)];
    p1.lineWidth = lineW;
    p1.lineCapStyle = kCGLineCapButt;
    p1.lineJoinStyle = kCGLineJoinRound;
    [p1 stroke];

    UIBezierPath *p2 = [UIBezierPath bezierPath];
    [p2 moveToPoint:CGPointMake(w * 0.08, h * 0.69)];
    [p2 addLineToPoint:CGPointMake(w * 0.20, h * 0.69)];
    [p2 addCurveToPoint:CGPointMake(w * 0.58, h * 0.31)
          controlPoint1:CGPointMake(w * 0.38, h * 0.69)
          controlPoint2:CGPointMake(w * 0.40, h * 0.31)];
    [p2 addLineToPoint:CGPointMake(w * 0.72, h * 0.31)];
    p2.lineWidth = lineW;
    p2.lineCapStyle = kCGLineCapButt;
    p2.lineJoinStyle = kCGLineJoinRound;
    [p2 stroke];

    UIBezierPath *a1 = [UIBezierPath bezierPath];
    [a1 moveToPoint:CGPointMake(w * 0.89, h * 0.31)];
    [a1 addLineToPoint:CGPointMake(w * 0.70, h * 0.16)];
    [a1 addLineToPoint:CGPointMake(w * 0.70, h * 0.46)];
    [a1 closePath];
    [a1 fill];

    UIBezierPath *a2 = [UIBezierPath bezierPath];
    [a2 moveToPoint:CGPointMake(w * 0.89, h * 0.69)];
    [a2 addLineToPoint:CGPointMake(w * 0.70, h * 0.54)];
    [a2 addLineToPoint:CGPointMake(w * 0.70, h * 0.84)];
    [a2 closePath];
    [a2 fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)vectorRepeatIconWithColor:(UIColor *)color size:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [color setStroke];
    [color setFill];

    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat lineW = MAX(1.8, h * 0.095);
    CGFloat radius = MIN(w, h) * 0.16;

    UIBezierPath *topPath = [UIBezierPath bezierPath];
    [topPath moveToPoint:CGPointMake(w * 0.10, h * 0.45)];
    [topPath addLineToPoint:CGPointMake(w * 0.10, h * 0.25 + radius)];
    [topPath addArcWithCenter:CGPointMake(w * 0.10 + radius, h * 0.25 + radius)
                       radius:radius
                   startAngle:M_PI
                     endAngle:1.5 * M_PI
                    clockwise:YES];
    [topPath addLineToPoint:CGPointMake(w * 0.69, h * 0.25)];
    topPath.lineWidth = lineW;
    topPath.lineCapStyle = kCGLineCapButt;
    topPath.lineJoinStyle = kCGLineJoinRound;
    [topPath stroke];

    UIBezierPath *topArrow = [UIBezierPath bezierPath];
    [topArrow moveToPoint:CGPointMake(w * 0.88, h * 0.25)];
    [topArrow addLineToPoint:CGPointMake(w * 0.67, h * 0.11)];
    [topArrow addLineToPoint:CGPointMake(w * 0.67, h * 0.39)];
    [topArrow closePath];
    [topArrow fill];

    UIBezierPath *botPath = [UIBezierPath bezierPath];
    [botPath moveToPoint:CGPointMake(w * 0.90, h * 0.55)];
    [botPath addLineToPoint:CGPointMake(w * 0.90, h * 0.75 - radius)];
    [botPath addArcWithCenter:CGPointMake(w * 0.90 - radius, h * 0.75 - radius)
                       radius:radius
                   startAngle:0.0
                     endAngle:0.5 * M_PI
                    clockwise:YES];
    [botPath addLineToPoint:CGPointMake(w * 0.31, h * 0.75)];
    botPath.lineWidth = lineW;
    botPath.lineCapStyle = kCGLineCapButt;
    botPath.lineJoinStyle = kCGLineJoinRound;
    [botPath stroke];

    UIBezierPath *botArrow = [UIBezierPath bezierPath];
    [botArrow moveToPoint:CGPointMake(w * 0.12, h * 0.75)];
    [botArrow addLineToPoint:CGPointMake(w * 0.33, h * 0.61)];
    [botArrow addLineToPoint:CGPointMake(w * 0.33, h * 0.89)];
    [botArrow closePath];
    [botArrow fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)playerPlayIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_play"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(20.0, 20.0);
    return [self vectorPlayIconWithColor:color size:sz];
}

- (UIImage *)playerPauseIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_pause"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(20.0, 20.0);
    return [self vectorPauseIconWithColor:color size:sz];
}

- (UIImage *)playerPrevIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_prev"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(22.0, 20.0);
    return [self vectorPrevIconWithColor:color size:sz];
}

- (UIImage *)playerNextIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_next"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(22.0, 20.0);
    return [self vectorNextIconWithColor:color size:sz];
}

- (UIImage *)playerShuffleIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_shuffle"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(18.0, 18.0);
    return [self vectorShuffleIconWithColor:color size:sz];
}

- (UIImage *)playerRepeatIconWithColor:(UIColor *)color {
    UIImage *raw = [UIImage imageNamed:@"player_repeat"];
    if (self.currentIconSet == YMIconSetTypeFiles && raw) {
        return [raw ym_tintedImageWithColor:color];
    }
    CGSize sz = (raw && raw.size.width > 0) ? raw.size : CGSizeMake(18.0, 18.0);
    return [self vectorRepeatIconWithColor:color size:sz];
}

- (UIImage *)tabBarIconForIndex:(NSUInteger)index selected:(BOOL)selected {
    UIColor *iconColor = selected
        ? [self playerAccentColor]
        : [UIColor colorWithWhite:0.68 alpha:1.0];

    NSArray *fileNames = @[@"tab_likes.png", @"tab_player.png", @"tab_search.png", @"tab_downloads.png", @"tab_settings.png"];
    UIImage *rawFileImg = (index < fileNames.count) ? [UIImage imageNamed:fileNames[index]] : nil;

    CGSize iconSize = (rawFileImg && rawFileImg.size.width > 0 && rawFileImg.size.height > 0)
        ? rawFileImg.size
        : CGSizeMake(30.0, 30.0);

    if (self.currentIconSet == YMIconSetTypeFiles && rawFileImg) {
        return [rawFileImg ym_tintedImageWithColor:iconColor];
    }

    switch (index) {
        case 0: return [self vectorHeartImageFilled:NO color:iconColor size:iconSize];
        case 1: return [self vectorMusicNoteWithColor:iconColor size:iconSize];
        case 2: return [self vectorSearchIconWithColor:iconColor size:iconSize];
        case 3: return [self vectorDownloadsIconWithColor:iconColor size:iconSize];
        case 4: return [self vectorSettingsIconWithColor:iconColor size:iconSize];
        default: return nil;
    }
}

- (void)applyThemeToNavigationController:(UINavigationController *)nav {
    if (!nav) return;
    UIViewController *rootVC = nav.viewControllers.firstObject;
    BOOL isPlayer = [rootVC isKindOfClass:[YMPlayerViewController class]];

    if (isPlayer) {
        // В плеере шапка всегда стоковая чёрная глянцевая (UIBarStyleBlackOpaque)
        nav.navigationBar.barStyle = UIBarStyleBlackOpaque;
        nav.navigationBar.tintColor = nil;
        nav.navigationBar.titleTextAttributes = nil;
    } else {
        nav.navigationBar.barStyle = UIBarStyleDefault;
        nav.navigationBar.tintColor = [self accentColor];
        nav.navigationBar.titleTextAttributes = nil;
    }
    if ([nav.navigationBar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        [nav.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    }
    [nav.navigationBar setNeedsLayout];
    [nav.navigationBar setNeedsDisplay];
}

- (void)applyThemeToSearchBar:(UISearchBar *)searchBar {
    if (!searchBar) return;
    searchBar.barStyle = UIBarStyleDefault;
    searchBar.tintColor = [self accentColor];
    [searchBar setNeedsLayout];
    [searchBar setNeedsDisplay];
}

- (void)applyThemeToTabBarController:(UITabBarController *)tabBarController {
    if (!tabBarController) return;
    UITabBar *tabBar = tabBarController.tabBar;
    UIColor *ios6GrayColor = [UIColor colorWithWhite:0.68 alpha:1.0];

    for (NSUInteger i = 0; i < tabBarController.viewControllers.count; i++) {
        UIViewController *vc = tabBarController.viewControllers[i];
        if ([vc isKindOfClass:[UINavigationController class]]) {
            [self applyThemeToNavigationController:(UINavigationController *)vc];
        }

        UITabBarItem *item = vc.tabBarItem;
        if (i == 0) {
            item.title = @"Любимое";
        }
        UIImage *unselIcon = [self tabBarIconForIndex:i selected:NO];
        UIImage *selIcon = [self tabBarIconForIndex:i selected:YES];

        if ([item respondsToSelector:@selector(setFinishedSelectedImage:withFinishedUnselectedImage:)]) {
            [item setFinishedSelectedImage:selIcon withFinishedUnselectedImage:unselIcon];
        } else if ([item respondsToSelector:@selector(setSelectedImage:)]) {
            item.image = unselIcon;
            item.selectedImage = selIcon;
        }
        [item setTitleTextAttributes:@{UITextAttributeTextColor: ios6GrayColor} forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor]} forState:UIControlStateSelected];
    }

    if ([tabBar respondsToSelector:@selector(setBackgroundImage:)]) {
        tabBar.backgroundImage = nil;
    }
    if ([tabBar respondsToSelector:@selector(setSelectionIndicatorImage:)]) {
        tabBar.selectionIndicatorImage = nil;
    }
    [tabBar setNeedsLayout];
    [tabBar setNeedsDisplay];
}

@end

#pragma mark - 0. YMAuthViewController

@interface YMAuthViewController ()
@property (nonatomic, strong) UINavigationBar *navBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSTimer *pollTimer;
@property (nonatomic, copy) NSString *deviceCode;
@property (nonatomic, copy) NSString *userCode;
@property (nonatomic, copy) NSString *statusText;
@property (nonatomic, assign) NSInteger pollInterval;
@property (nonatomic, assign) BOOL isPollingRequestInFlight;
@end

@implementation YMAuthViewController

- (void)dealloc {
    [_pollTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.userCode = @"• • • •";
    self.statusText = @"Генерация кода...";

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, w, 44.0)];
    _navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"Вход в Яндекс"];
    navItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                               target:self
                                                                               action:@selector(requestNewDeviceCode)];
    _navBar.items = @[navItem];
    [self.view addSubview:_navBar];

    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44.0, w, h - 44.0) style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [self applyTheme];
    [self requestNewDeviceCode];
}

- (void)applyTheme {
    _navBar.tintColor = [[YMThemeManager shared] accentColor];
    [_tableView reloadData];
}

- (void)requestNewDeviceCode {
    [self.pollTimer invalidate];
    self.pollTimer = nil;
    self.deviceCode = nil;
    self.userCode = @"• • • •";
    self.statusText = @"Генерация кода...";
    [self.tableView reloadData];

    [[YMApiClient shared] startDeviceAuthWithCompletion:^(NSString *deviceCode, NSString *userCode, NSString *verificationURL, NSInteger interval, NSError *error) {
        if (error || !deviceCode || deviceCode.length == 0 || !userCode || userCode.length == 0) {
            self.userCode = @"Ошибка";
            self.statusText = @"Проверьте подключение к прокси-серверу";
            [self.tableView reloadData];
            return;
        }
        self.deviceCode = deviceCode;
        self.userCode = userCode;
        self.statusText = @"Ожидание подтверждения на странице ya.ru/device...";
        [self.tableView reloadData];

        self.pollInterval = MAX(3, interval);
        self.pollTimer = [NSTimer scheduledTimerWithTimeInterval:self.pollInterval
                                                          target:self
                                                        selector:@selector(pollAuthStatus)
                                                        userInfo:nil
                                                         repeats:YES];
    }];
}

- (void)pollAuthStatus {
    if (!self.deviceCode || self.deviceCode.length == 0 || self.isPollingRequestInFlight) return;
    self.isPollingRequestInFlight = YES;

    [[YMApiClient shared] pollDeviceAuthWithCode:self.deviceCode completion:^(BOOL authorized, NSString *token, NSString *accountName, NSError *error) {
        self.isPollingRequestInFlight = NO;
        if (authorized) {
            [self.pollTimer invalidate];
            self.pollTimer = nil;
            self.statusText = @"Вход выполнен!";
            [self.tableView reloadData];
            [[NSNotificationCenter defaultCenter] postNotificationName:YMLikesUpdatedNotification object:nil];
            if (self.onAuthSuccess) {
                self.onAuthSuccess();
            }
        }
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == 0) ? 1 : 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Введите этот код на ya.ru/device";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return self.statusText;
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (indexPath.section == 0) ? 64.0 : 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *codeCellId = @"AuthCodeCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:codeCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:codeCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:28.0];
        }
        cell.textLabel.text = self.userCode;
        cell.textLabel.textColor = [[YMThemeManager shared] accentColor] ?: [UIColor colorWithRed:0.20 green:0.35 blue:0.65 alpha:1.0];
        return cell;
    }

    static NSString *btnCellId = @"AuthActionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:btnCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:btnCellId];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0];
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Скопировать код";
    } else {
        cell.textLabel.text = @"Запросить новый код";
    }
    cell.textLabel.textColor = [UIColor colorWithRed:0.20 green:0.35 blue:0.65 alpha:1.0];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0 && self.userCode.length > 0) {
            [UIPasteboard generalPasteboard].string = self.userCode;
            self.statusText = @"Код скопирован в буфер обмена.";
            [self.tableView reloadData];
        } else if (indexPath.row == 1) {
            [self requestNewDeviceCode];
        }
    }
}

@end

#pragma mark - YMSwipeTrackCell

@interface YMSwipeTrackCell ()
@property (nonatomic, strong) UIButton *nativeAddButton;
@end

@implementation YMSwipeTrackCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier]) {
        self.selectionStyle = UITableViewCellSelectionStyleBlue;
        self.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
        self.detailTextLabel.font = [UIFont systemFontOfSize:13.0];

        _nativeAddButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
        [_nativeAddButton addTarget:self action:@selector(onPlusTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (UIImage *)resizedCoverImage:(UIImage *)image {
    if (!image) return nil;
    CGSize sz = CGSizeMake(44.0, 44.0);
    UIGraphicsBeginImageContextWithOptions(sz, YES, 0.0);
    [image drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *res = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return res;
}

- (UIImage *)placeholderCoverImage {
    static UIImage *placeholder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize sz = CGSizeMake(44.0, 44.0);
        UIGraphicsBeginImageContextWithOptions(sz, YES, 0.0);
        [[UIColor colorWithWhite:0.90 alpha:1.0] setFill];
        UIRectFill(CGRectMake(0, 0, sz.width, sz.height));
        UIImage *note = [[YMThemeManager shared] tabBarIconForIndex:1 selected:NO];
        if (note) {
            [note drawInRect:CGRectMake(10.0, 10.0, 24.0, 24.0)];
        }
        placeholder = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return placeholder;
}

- (void)setShowPlusButton:(BOOL)showPlusButton {
    _showPlusButton = showPlusButton;
    self.accessoryView = showPlusButton ? self.nativeAddButton : nil;
}

- (void)configureWithTrack:(YMTrack *)track {
    self.track = track;
    self.textLabel.text = track.title;
    self.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", track.artist ?: @"", [track formattedDuration]];
    self.imageView.image = [self placeholderCoverImage];

    if (track.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:track.localCoverPath]) {
        UIImage *local = [UIImage imageWithContentsOfFile:track.localCoverPath];
        if (local) {
            self.imageView.image = [self resizedCoverImage:local];
            return;
        }
    }

    NSString *expectedId = [track.trackId copy];
    __weak typeof(self) weakSelf = self;
    [[YMApiClient shared] loadImageWithURL:track.coverURL completion:^(UIImage *image) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && image && [strongSelf.track.trackId isEqualToString:expectedId]) {
            strongSelf.imageView.image = [strongSelf resizedCoverImage:image];
            [strongSelf setNeedsLayout];
        }
    }];
}

- (void)onPlusTapped {
    if ([self.delegate respondsToSelector:@selector(trackCellDidTapPlus:)]) {
        [self.delegate trackCellDidTapPlus:self];
    }
}

@end

#pragma mark - 1. YMLikesViewController (Вкладка "Любимое")

@interface YMLikesViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSArray *allTracks;
@property (nonatomic, strong) NSMutableArray *filteredTracks;
@property (nonatomic, strong) YMTrack *actionSheetTrack;
@property (nonatomic, copy) NSString *filterQuery;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation YMLikesViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Любимое";
    self.navigationItem.title = @"Любимое";
    self.tabBarItem.title = @"Любимое";
    if (self.navigationController) {
        self.navigationController.tabBarItem.title = @"Любимое";
    }

    self.allTracks = @[];
    self.filteredTracks = [NSMutableArray array];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Изменить"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(toggleEditMode)];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0)];
    _searchBar.placeholder = @"Поиск";
    _searchBar.delegate = self;

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 54.0;
    _tableView.tableHeaderView = _searchBar;
    _tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:_tableView];

    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(loadLikesFromServer) forControlEvents:UIControlEventValueChanged];
    [_tableView addSubview:_refreshControl];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadLikesFromServer) name:YMLikesUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadLikesFromServer) name:YMAuthStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    if ([[YMApiClient shared] isAuthorized]) {
        [self loadLikesFromServer];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    if (self.allTracks.count == 0 && !self.isLoading && [[YMApiClient shared] isAuthorized]) {
        [self loadLikesFromServer];
    }
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToSearchBar:self.searchBar];
    [self.tableView reloadData];
}

- (void)loadLikesFromServer {
    if (self.isLoading || ![[YMApiClient shared] isAuthorized]) {
        [self.refreshControl endRefreshing];
        return;
    }
    self.isLoading = YES;
    [[YMApiClient shared] fetchLikesWithCompletion:^(NSArray *tracks, NSError *error) {
        self.isLoading = NO;
        [self.refreshControl endRefreshing];
        if (tracks) {
            self.allTracks = tracks;
            [self applyFilter];
        }
    }];
}

- (void)applyFilter {
    [self.filteredTracks removeAllObjects];
    if (!self.filterQuery || self.filterQuery.length == 0) {
        [self.filteredTracks addObjectsFromArray:self.allTracks];
    } else {
        NSString *q = [self.filterQuery lowercaseString];
        for (YMTrack *t in self.allTracks) {
            if ([[t.title lowercaseString] rangeOfString:q].location != NSNotFound ||
                [[t.artist lowercaseString] rangeOfString:q].location != NSNotFound) {
                [self.filteredTracks addObject:t];
            }
        }
    }
    [self.tableView reloadData];
}

- (void)toggleEditMode {
    BOOL newEdit = !self.tableView.editing;
    [self.tableView setEditing:newEdit animated:YES];
    self.navigationItem.rightBarButtonItem.title = newEdit ? @"Готово" : @"Изменить";
    self.navigationItem.rightBarButtonItem.style = newEdit ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
    self.navigationItem.leftBarButtonItem = newEdit
        ? [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStyleDone target:self action:@selector(deleteSelectedTracks)]
        : nil;
}

- (void)deleteSelectedTracks {
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if (selectedRows.count == 0) return;
    NSMutableArray *ids = [NSMutableArray array];
    NSMutableArray *objs = [NSMutableArray array];
    for (NSIndexPath *ip in selectedRows) {
        YMTrack *t = self.filteredTracks[ip.row];
        [ids addObject:t.trackId];
        [objs addObject:t];
    }
    [[YMApiClient shared] removeTracksFromLikes:ids completion:^(BOOL success, NSError *error) {
        if (success) {
            NSMutableArray *upd = [self.allTracks mutableCopy];
            [upd removeObjectsInArray:objs];
            self.allTracks = upd;
            [self applyFilter];
            [self toggleEditMode];
        }
    }];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    self.filterQuery = @"";
    [self applyFilter];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.filterQuery = searchText;
    [self applyFilter];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"LikesTrackCell";
    YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.showPlusButton = NO;
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    }
    [cell configureWithTrack:self.filteredTracks[indexPath.row]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Удалить";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.row < (NSInteger)self.filteredTracks.count) {
        YMTrack *t = self.filteredTracks[indexPath.row];
        [[YMApiClient shared] removeTracksFromLikes:@[t.trackId] completion:^(BOOL success, NSError *error) {
            if (success) {
                NSMutableArray *upd = [self.allTracks mutableCopy];
                [upd removeObject:t];
                self.allTracks = upd;
                [self applyFilter];
            }
        }];
    }
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.filteredTracks.count) return;
    self.actionSheetTrack = self.filteredTracks[indexPath.row];
    NSString *sheetTitle = [NSString stringWithFormat:@"%@ — %@", self.actionSheetTrack.artist, self.actionSheetTrack.title];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:sheetTitle
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:@"Удалить из Любимого"
                                              otherButtonTitles:@"Скачать в Загрузки", nil];
    if (self.tabBarController.tabBar) {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    } else {
        [sheet showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    YMTrack *t = self.actionSheetTrack;
    self.actionSheetTrack = nil;
    if (!t) return;

    if (buttonIndex == actionSheet.destructiveButtonIndex) {
        [[YMApiClient shared] removeTracksFromLikes:@[t.trackId] completion:^(BOOL success, NSError *error) {
            if (success) {
                NSMutableArray *upd = [self.allTracks mutableCopy];
                [upd removeObject:t];
                self.allTracks = upd;
                [self applyFilter];
            }
        }];
    } else if (buttonIndex == 1) {
        [[YMDownloadManager shared] downloadTrack:t completion:^(BOOL success, NSError *error) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Загрузки"
                                                        message:success ? @"Трек сохранён в Загрузки" : @"Ошибка загрузки"
                                                       delegate:nil
                                              cancelButtonTitle:@"ОК"
                                              otherButtonTitles:nil];
            [a show];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.editing) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[YMPlayerManager shared] playQueue:self.filteredTracks startIndex:indexPath.row];
    self.tabBarController.selectedIndex = 1;
}

@end

#pragma mark - 2. YMPlayerViewController (100% нативный UIKit: чёрные UIToolbar, белые UIBarButtonItem, акцентные ползунки и активные кнопки)

@interface YMPlayerViewController ()
@property (nonatomic, strong) UIView *stageView;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UIImageView *reflectionImageView;

@property (nonatomic, strong) UIToolbar *topAuxToolbar;
@property (nonatomic, strong) UIBarButtonItem *myWaveBarItem;
@property (nonatomic, strong) UIBarButtonItem *shuffleBarItem;
@property (nonatomic, strong) UIBarButtonItem *repeatBarItem;
@property (nonatomic, strong) UIBarButtonItem *likeBarItem;

@property (nonatomic, strong) UIToolbar *scrubberToolbar;
@property (nonatomic, strong) UISlider *seekSlider;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *remainingLabel;

@property (nonatomic, strong) UIToolbar *bottomTransportToolbar;
@property (nonatomic, strong) UIBarButtonItem *prevBarItem;
@property (nonatomic, strong) UIBarButtonItem *playPauseBarItem;
@property (nonatomic, strong) UIBarButtonItem *nextBarItem;

@property (nonatomic, strong) UIToolbar *volumeDockToolbar;
@property (nonatomic, strong) MPVolumeView *volumeView;

@property (nonatomic, strong) UIImage *rawLoadedCoverImage;
@property (nonatomic, assign) CGFloat lastRenderedCoverSide;
@property (nonatomic, assign) BOOL isScrubbing;
@property (nonatomic, copy) NSString *displayedTrackId;
@end

@implementation YMPlayerViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    // 1. Трёхстрочный заголовок в штатном чёрном UINavigationBar (Исполнитель / Трек / Альбом)
    UIView *titleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 40)];

    UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 1, 200, 13)];
    artistLabel.tag = 102;
    artistLabel.font = [UIFont boldSystemFontOfSize:11.0];
    artistLabel.textColor = [UIColor colorWithWhite:0.78 alpha:1.0];
    artistLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.75];
    artistLabel.shadowOffset = CGSizeMake(0, -1);
    artistLabel.textAlignment = NSTextAlignmentCenter;
    artistLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:artistLabel];

    UILabel *titleTrackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 13, 200, 15)];
    titleTrackLabel.tag = 101;
    titleTrackLabel.font = [UIFont boldSystemFontOfSize:13.0];
    titleTrackLabel.textColor = [UIColor whiteColor];
    titleTrackLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.75];
    titleTrackLabel.shadowOffset = CGSizeMake(0, -1);
    titleTrackLabel.textAlignment = NSTextAlignmentCenter;
    titleTrackLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:titleTrackLabel];

    UILabel *albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 27, 200, 12)];
    albumLabel.tag = 103;
    albumLabel.font = [UIFont systemFontOfSize:11.0];
    albumLabel.textColor = [UIColor colorWithWhite:0.74 alpha:1.0];
    albumLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.75];
    albumLabel.shadowOffset = CGSizeMake(0, -1);
    albumLabel.textAlignment = NSTextAlignmentCenter;
    albumLabel.backgroundColor = [UIColor clearColor];
    [titleView addSubview:albumLabel];

    self.navigationItem.titleView = titleView;

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    // 2. Чёрная глянцевая сцена обложки с зеркальным отражением
    _stageView = [[UIView alloc] initWithFrame:self.view.bounds];
    _stageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _stageView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_stageView];

    _coverImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _coverImageView.contentMode = UIViewContentModeScaleToFill;
    _coverImageView.backgroundColor = [UIColor blackColor];
    [_stageView addSubview:_coverImageView];

    _reflectionImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _reflectionImageView.contentMode = UIViewContentModeScaleToFill;
    _reflectionImageView.backgroundColor = [UIColor clearColor];
    [_stageView addSubview:_reflectionImageView];

    // 3. Штатный чёрный UIToolbar для кнопок режимов (Моя Волна, Перемешка, Повтор, Лайк)
    _topAuxToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, w, 40.0)];
    _topAuxToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _topAuxToolbar.barStyle = UIBarStyleBlackTranslucent;
    _topAuxToolbar.tintColor = nil; // всегда чёрный скевоморфный тулбар iOS 6
    [self.view addSubview:_topAuxToolbar];

    _myWaveBarItem = [[UIBarButtonItem alloc] initWithTitle:@"✦ Моя Волна"
                                                      style:UIBarButtonItemStyleBordered
                                                     target:self
                                                     action:@selector(onMyWaveTapped)];

    _shuffleBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] playerShuffleIconWithColor:[UIColor whiteColor]]
                                                       style:UIBarButtonItemStyleBordered
                                                      target:self
                                                      action:@selector(onShuffleTapped)];

    _repeatBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] playerRepeatIconWithColor:[UIColor whiteColor]]
                                                      style:UIBarButtonItemStyleBordered
                                                     target:self
                                                     action:@selector(onRepeatTapped)];

    _likeBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] vectorHeartImageFilled:NO color:[UIColor whiteColor] size:CGSizeMake(17.0, 17.0)]
                                                    style:UIBarButtonItemStyleBordered
                                                   target:self
                                                   action:@selector(onLikeTapped)];

    UIBarButtonItem *topFlex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    _topAuxToolbar.items = @[_myWaveBarItem, topFlex, _shuffleBarItem, _repeatBarItem, _likeBarItem];

    // 4. Штатный чёрный UIToolbar для полосы перемотки времени
    _scrubberToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 40.0, w, 28.0)];
    _scrubberToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _scrubberToolbar.barStyle = UIBarStyleBlackTranslucent;
    _scrubberToolbar.tintColor = nil;
    [self.view addSubview:_scrubberToolbar];

    _elapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(8.0, 7.0, 42.0, 14.0)];
    _elapsedLabel.font = [UIFont boldSystemFontOfSize:11.0];
    _elapsedLabel.textColor = [UIColor whiteColor];
    _elapsedLabel.shadowColor = [UIColor blackColor];
    _elapsedLabel.shadowOffset = CGSizeMake(0, -1);
    _elapsedLabel.textAlignment = NSTextAlignmentRight;
    _elapsedLabel.backgroundColor = [UIColor clearColor];
    _elapsedLabel.text = @"0:00";
    [_scrubberToolbar addSubview:_elapsedLabel];

    _remainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 50.0, 7.0, 42.0, 14.0)];
    _remainingLabel.font = [UIFont boldSystemFontOfSize:11.0];
    _remainingLabel.textColor = [UIColor whiteColor];
    _remainingLabel.shadowColor = [UIColor blackColor];
    _remainingLabel.shadowOffset = CGSizeMake(0, -1);
    _remainingLabel.textAlignment = NSTextAlignmentLeft;
    _remainingLabel.backgroundColor = [UIColor clearColor];
    _remainingLabel.text = @"-0:00";
    [_scrubberToolbar addSubview:_remainingLabel];

    _seekSlider = [[UISlider alloc] initWithFrame:CGRectMake(56.0, 2.0, w - 112.0, 24.0)];
    _seekSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _seekSlider.minimumValue = 0.0;
    _seekSlider.maximumValue = 1.0;
    [_seekSlider addTarget:self action:@selector(onSeekTouchDown) forControlEvents:UIControlEventTouchDown];
    [_seekSlider addTarget:self action:@selector(onSeekValueChanged) forControlEvents:UIControlEventValueChanged];
    [_seekSlider addTarget:self action:@selector(onSeekTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [_scrubberToolbar addSubview:_seekSlider];

    // 5. Нижний штатный чёрный UIToolbar для кнопок управления (Prev / Play-Pause / Next)
    _bottomTransportToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, h - 80.0, w, 44.0)];
    _bottomTransportToolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _bottomTransportToolbar.barStyle = UIBarStyleBlackTranslucent;
    _bottomTransportToolbar.tintColor = nil;
    [self.view addSubview:_bottomTransportToolbar];

    _prevBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] playerPrevIconWithColor:[UIColor whiteColor]]
                                                    style:UIBarButtonItemStylePlain
                                                   target:self
                                                   action:@selector(onPrev)];

    _playPauseBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] playerPlayIconWithColor:[UIColor whiteColor]]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(onPlayPause)];

    _nextBarItem = [[UIBarButtonItem alloc] initWithImage:[[YMThemeManager shared] playerNextIconWithColor:[UIColor whiteColor]]
                                                    style:UIBarButtonItemStylePlain
                                                   target:self
                                                   action:@selector(onNext)];

    // 6. Нижний штатный чёрный UIToolbar для системного ползунка громкости MPVolumeView
    _volumeDockToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, h - 36.0, w, 36.0)];
    _volumeDockToolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _volumeDockToolbar.barStyle = UIBarStyleBlackOpaque;
    _volumeDockToolbar.tintColor = nil;
    [self.view addSubview:_volumeDockToolbar];

    _volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(24.0, 6.0, w - 48.0, 24.0)];
    _volumeView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_volumeDockToolbar addSubview:_volumeView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPlayerUI) name:YMPlayerStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPlayerUI) name:YMLikesUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self updateRenderedCoverAndReflectionAnimated:NO];
    [self refreshPlayerUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    _stageView.frame = self.view.bounds;
    _topAuxToolbar.frame = CGRectMake(0, 0, w, 40.0);
    _scrubberToolbar.frame = CGRectMake(0, 40.0, w, 28.0);
    _elapsedLabel.frame = CGRectMake(8.0, 7.0, 42.0, 14.0);
    _remainingLabel.frame = CGRectMake(w - 50.0, 7.0, 42.0, 14.0);
    _seekSlider.frame = CGRectMake(56.0, 2.0, w - 112.0, 24.0);

    _bottomTransportToolbar.frame = CGRectMake(0, h - 80.0, w, 44.0);
    _volumeDockToolbar.frame = CGRectMake(0, h - 36.0, w, 36.0);
    _volumeView.frame = CGRectMake(24.0, 6.0, w - 48.0, 24.0);

    CGFloat stageTop = 72.0;
    CGFloat stageBottom = h - 82.0;
    CGFloat availH = MAX(100.0, stageBottom - stageTop);

    CGFloat reflectionRatio = 0.18;
    CGFloat maxSideByHeight = floorf(availH / (1.0 + reflectionRatio));
    CGFloat maxSideByWidth = w - 24.0;
    CGFloat side = MIN(maxSideByWidth, maxSideByHeight);
    CGFloat reflH = floorf(side * reflectionRatio);

    CGFloat totalArtBlockH = side + reflH;
    CGFloat coverX = floorf((w - side) / 2.0);
    CGFloat coverY = stageTop + floorf((availH - totalArtBlockH) / 2.0);

    _coverImageView.frame = CGRectMake(coverX, coverY, side, side);
    _reflectionImageView.frame = CGRectMake(coverX, coverY + side + 1.0, side, reflH);

    if (fabs(self.lastRenderedCoverSide - side) > 1.0) {
        self.lastRenderedCoverSide = side;
        [self updateRenderedCoverAndReflectionAnimated:NO];
    }
}

- (void)updateRenderedCoverAndReflectionAnimated:(BOOL)animated {
    YMThemeManager *tm = [YMThemeManager shared];
    CGFloat side = self.coverImageView.bounds.size.width;
    if (side <= 0) side = 220.0;
    CGFloat reflH = self.reflectionImageView.bounds.size.height;
    if (reflH <= 0) reflH = floorf(side * 0.18);

    UIImage *framedCover = [tm framedAlbumImageFromImage:self.rawLoadedCoverImage side:side];
    UIImage *reflection = [tm reflectionImageFromAlbumImage:framedCover side:side reflectionHeight:reflH];

    if (animated) {
        [UIView transitionWithView:self.stageView
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            self.coverImageView.image = framedCover;
                            self.reflectionImageView.image = reflection;
                        }
                        completion:nil];
    } else {
        self.coverImageView.image = framedCover;
        self.reflectionImageView.image = reflection;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    [self refreshPlayerUI];
}

// Нативное окрашивание заполненной части системного ползунка громкости внутри MPVolumeView
- (void)applyAccentToNativeVolumeSlider:(UIColor *)accentColor {
    for (UIView *sub in self.volumeView.subviews) {
        if ([sub isKindOfClass:[UISlider class]]) {
            UISlider *volSlider = (UISlider *)sub;
            if ([volSlider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
                volSlider.minimumTrackTintColor = accentColor;
            }
        }
    }
}

- (void)updateNativeToolbarButtons {
    YMThemeManager *tm = [YMThemeManager shared];
    YMPlayerManager *pm = [YMPlayerManager shared];
    UIColor *accent = [tm playerAccentColor];
    UIColor *white = [UIColor whiteColor];

    BOOL waveActive = pm.isMyWaveMode;
    BOOL shuffleActive = pm.isShuffleEnabled && !waveActive;
    BOOL repeatActive = pm.isRepeatTrackEnabled;
    BOOL isLiked = pm.currentTrack ? [[YMApiClient shared] isTrackLiked:pm.currentTrack.trackId] : NO;

    // В нативном UIBarButtonItem: tintColor = nil делает кнопку стандартной чёрной, а tintColor = accent делает её цветной глянцевой
    if ([self.myWaveBarItem respondsToSelector:@selector(setTintColor:)]) {
        self.myWaveBarItem.tintColor = waveActive ? accent : nil;
    }
    [self.myWaveBarItem setTitleTextAttributes:@{UITextAttributeTextColor: white} forState:UIControlStateNormal];

    self.shuffleBarItem.enabled = !waveActive;
    if ([self.shuffleBarItem respondsToSelector:@selector(setTintColor:)]) {
        self.shuffleBarItem.tintColor = shuffleActive ? accent : nil;
    }
    self.shuffleBarItem.image = [tm playerShuffleIconWithColor:white];

    self.repeatBarItem.enabled = YES;
    if ([self.repeatBarItem respondsToSelector:@selector(setTintColor:)]) {
        self.repeatBarItem.tintColor = repeatActive ? accent : nil;
    }
    self.repeatBarItem.image = [tm playerRepeatIconWithColor:white];

    self.likeBarItem.enabled = (pm.currentTrack != nil);
    if ([self.likeBarItem respondsToSelector:@selector(setTintColor:)]) {
        self.likeBarItem.tintColor = isLiked ? accent : nil;
    }
    self.likeBarItem.image = [tm vectorHeartImageFilled:isLiked color:white size:CGSizeMake(17.0, 17.0)];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];

    UIColor *accent = [tm playerAccentColor];
    UIColor *white = [UIColor whiteColor];

    // Все панели плеера всегда остаются чёрными стоковыми UIToolbar
    self.topAuxToolbar.tintColor = nil;
    self.scrubberToolbar.tintColor = nil;
    self.bottomTransportToolbar.tintColor = nil;
    self.volumeDockToolbar.tintColor = nil;

    // Нативный акцентный цвет для ползунков времени и громкости
    if ([self.seekSlider respondsToSelector:@selector(setMinimumTrackTintColor:)]) {
        self.seekSlider.minimumTrackTintColor = accent;
    }
    [self applyAccentToNativeVolumeSlider:accent];

    // Кнопки управления всегда чисто белые
    self.prevBarItem.image = [tm playerPrevIconWithColor:white];
    self.nextBarItem.image = [tm playerNextIconWithColor:white];

    [self updateNativeToolbarButtons];
    if (!self.rawLoadedCoverImage) {
        [self updateRenderedCoverAndReflectionAnimated:NO];
    }
    [self refreshPlayerUI];
}

- (NSString *)formatSeconds:(NSTimeInterval)sec {
    NSInteger s = (NSInteger)MAX(0, sec);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(s / 60), (long)(s % 60)];
}

- (void)refreshPlayerUI {
    YMPlayerManager *pm = [YMPlayerManager shared];
    YMThemeManager *tm = [YMThemeManager shared];
    UIColor *white = [UIColor whiteColor];

    self.playPauseBarItem.image = pm.isPlaying
        ? [tm playerPauseIconWithColor:white]
        : [tm playerPlayIconWithColor:white];

    UIBarButtonItem *flex1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex2 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex3 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *flex4 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.bottomTransportToolbar.items = @[flex1, self.prevBarItem, flex2, self.playPauseBarItem, flex3, self.nextBarItem, flex4];

    [self updateNativeToolbarButtons];
    [self applyAccentToNativeVolumeSlider:[tm playerAccentColor]];

    UIView *tv = self.navigationItem.titleView;
    UILabel *titleTrackLabel = (UILabel *)[tv viewWithTag:101];
    UILabel *artistLabel = (UILabel *)[tv viewWithTag:102];
    UILabel *albumLabel = (UILabel *)[tv viewWithTag:103];

    YMTrack *t = pm.currentTrack;
    if (!t) {
        titleTrackLabel.text = @"Не исполняется";
        artistLabel.text = @"";
        albumLabel.text = @"";
        self.seekSlider.value = 0.0;
        self.elapsedLabel.text = @"0:00";
        self.remainingLabel.text = @"-0:00";
        if (self.rawLoadedCoverImage != nil || self.displayedTrackId != nil) {
            self.rawLoadedCoverImage = nil;
            self.displayedTrackId = nil;
            [self updateRenderedCoverAndReflectionAnimated:YES];
        }
        return;
    }

    titleTrackLabel.text = t.title;
    artistLabel.text = t.artist;
    albumLabel.text = pm.isMyWaveMode ? @"Моя Волна" : (t.album.length > 0 ? t.album : @"");

    NSTimeInterval total = MAX(1.0, pm.totalDuration);
    self.seekSlider.maximumValue = total;
    if (!self.isScrubbing) {
        self.seekSlider.value = pm.currentTime;
        self.elapsedLabel.text = [self formatSeconds:pm.currentTime];
    }
    NSTimeInterval remaining = total - pm.currentTime;
    self.remainingLabel.text = [NSString stringWithFormat:@"-%@", [self formatSeconds:remaining]];

    if (![self.displayedTrackId isEqualToString:t.trackId]) {
        self.displayedTrackId = [t.trackId copy];
        self.rawLoadedCoverImage = nil;
        [self updateRenderedCoverAndReflectionAnimated:NO];

        if (t.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:t.localCoverPath]) {
            UIImage *localImg = [UIImage imageWithContentsOfFile:t.localCoverPath];
            if (localImg) {
                self.rawLoadedCoverImage = localImg;
                [self updateRenderedCoverAndReflectionAnimated:YES];
                return;
            }
        }

        for (YMTrack *dl in [[YMDownloadManager shared] downloadedTracks]) {
            if ([dl.trackId isEqualToString:t.trackId] && dl.localCoverPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:dl.localCoverPath]) {
                UIImage *dlImg = [UIImage imageWithContentsOfFile:dl.localCoverPath];
                if (dlImg) {
                    self.rawLoadedCoverImage = dlImg;
                    [self updateRenderedCoverAndReflectionAnimated:YES];
                    return;
                }
            }
        }

        NSString *expectedId = [t.trackId copy];
        NSString *hiResURL = t.highResCoverURL.length > 0 ? t.highResCoverURL : [YMTrack upgradeCoverURLToHighRes:t.coverURL];
        __weak typeof(self) weakSelf = self;
        [[YMApiClient shared] loadImageWithURL:hiResURL completion:^(UIImage *image) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf && image && [strongSelf.displayedTrackId isEqualToString:expectedId]) {
                strongSelf.rawLoadedCoverImage = image;
                [strongSelf updateRenderedCoverAndReflectionAnimated:YES];
            }
        }];
    }
}

- (void)onMyWaveTapped { [[YMPlayerManager shared] toggleMyWave]; }
- (void)onShuffleTapped { [[YMPlayerManager shared] toggleShuffle]; }
- (void)onRepeatTapped { [[YMPlayerManager shared] toggleRepeatTrack]; }
- (void)onLikeTapped {
    YMTrack *t = [YMPlayerManager shared].currentTrack;
    if (!t) return;
    [[YMApiClient shared] toggleLikeForTrack:t completion:^(BOOL isLiked) {
        [self updateNativeToolbarButtons];
    }];
}

- (void)onSeekTouchDown { self.isScrubbing = YES; }
- (void)onSeekValueChanged { self.elapsedLabel.text = [self formatSeconds:self.seekSlider.value]; }
- (void)onSeekTouchUp {
    [[YMPlayerManager shared] seekToSeconds:self.seekSlider.value];
    self.isScrubbing = NO;
}
- (void)onPrev { [[YMPlayerManager shared] previousTrack]; }
- (void)onPlayPause { [[YMPlayerManager shared] togglePlayPause]; }
- (void)onNext { [[YMPlayerManager shared] nextTrack]; }

@end

#pragma mark - 3. YMSearchViewController (Вкладка "Поиск")

@interface YMSearchViewController ()
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *foundTracks;
@property (nonatomic, strong) NSArray *foundArtists;
@property (nonatomic, strong) NSArray *foundAlbums;
@end

@implementation YMSearchViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Поиск";
    self.foundTracks = @[];
    self.foundArtists = @[];
    self.foundAlbums = @[];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0)];
    _searchBar.placeholder = @"Треки, исполнители, альбомы";
    _searchBar.delegate = self;

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 54.0;
    _tableView.tableHeaderView = _searchBar;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToSearchBar:self.searchBar];
    [self.tableView reloadData];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *q = searchBar.text;
    if (!q || q.length == 0) return;

    [[YMApiClient shared] searchWithQuery:q completion:^(NSArray *tracks, NSArray *artists, NSArray *albums, NSError *error) {
        if (error) return;
        self.foundTracks = tracks ?: @[];
        self.foundArtists = artists ?: @[];
        self.foundAlbums = albums ?: @[];
        [self.tableView reloadData];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return self.foundTracks.count ? @"Треки" : nil;
    if (section == 1) return self.foundArtists.count ? @"Исполнители" : nil;
    if (section == 2) return self.foundAlbums.count ? @"Альбомы" : nil;
    return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.foundTracks.count;
    if (section == 1) return self.foundArtists.count;
    return self.foundAlbums.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *tCellId = @"SearchTrackCell";
        YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:tCellId];
        if (!cell) {
            cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tCellId];
            cell.delegate = self;
            cell.showPlusButton = YES;
        }
        [cell configureWithTrack:self.foundTracks[indexPath.row]];
        return cell;
    }

    static NSString *metaId = @"MetaCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:metaId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:metaId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if (indexPath.section == 1) {
        NSDictionary *artist = self.foundArtists[indexPath.row];
        cell.textLabel.text = artist[@"name"];
        cell.detailTextLabel.text = artist[@"genres"];
    } else {
        NSDictionary *album = self.foundAlbums[indexPath.row];
        cell.textLabel.text = album[@"title"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%@)", album[@"artist"] ?: @"", album[@"year"] ?: @""];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [[YMPlayerManager shared] playQueue:self.foundTracks startIndex:indexPath.row];
        self.tabBarController.selectedIndex = 1;
    }
}

- (void)trackCellDidTapPlus:(YMSwipeTrackCell *)cell {
    if (!cell.track) return;
    [[YMApiClient shared] addTrackToLikes:cell.track.trackId completion:^(BOOL success, NSError *error) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Любимое"
                                                    message:success ? @"Трек добавлен в Любимое" : @"Ошибка добавления"
                                                   delegate:nil
                                          cancelButtonTitle:@"ОК"
                                          otherButtonTitles:nil];
        [a show];
    }];
}

@end

#pragma mark - 4. YMDownloadsViewController (Вкладка "Загрузки")

@interface YMDownloadsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *tracks;
@end

@implementation YMDownloadsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Загрузки";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Изменить"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(toggleEditMode)];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.rowHeight = 54.0;
    _tableView.allowsMultipleSelectionDuringEditing = YES;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadDownloads) name:YMDownloadsUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];

    [self applyTheme];
    [self reloadDownloads];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)applyTheme {
    [[YMThemeManager shared] applyThemeToNavigationController:self.navigationController];
    [self.tableView reloadData];
}

- (void)reloadDownloads {
    self.tracks = [[YMDownloadManager shared] downloadedTracks];
    [self.tableView reloadData];
}

- (void)toggleEditMode {
    BOOL newEdit = !self.tableView.editing;
    [self.tableView setEditing:newEdit animated:YES];
    self.navigationItem.rightBarButtonItem.title = newEdit ? @"Готово" : @"Изменить";
    self.navigationItem.rightBarButtonItem.style = newEdit ? UIBarButtonItemStyleDone : UIBarButtonItemStyleBordered;
    self.navigationItem.leftBarButtonItem = newEdit
        ? [[UIBarButtonItem alloc] initWithTitle:@"Удалить" style:UIBarButtonItemStyleDone target:self action:@selector(deleteSelectedDownloads)]
        : nil;
}

- (void)deleteSelectedDownloads {
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if (selectedRows.count == 0) return;
    NSMutableArray *ids = [NSMutableArray array];
    for (NSIndexPath *ip in selectedRows) {
        YMTrack *t = self.tracks[ip.row];
        [ids addObject:t.trackId];
    }
    [[YMDownloadManager shared] deleteDownloadedTracksWithIds:ids];
    [self toggleEditMode];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *dlCellId = @"DownloadCell";
    YMSwipeTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:dlCellId];
    if (!cell) {
        cell = [[YMSwipeTrackCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:dlCellId];
        cell.showPlusButton = NO;
    }
    [cell configureWithTrack:self.tracks[indexPath.row]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Удалить";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.row < (NSInteger)self.tracks.count) {
        YMTrack *t = self.tracks[indexPath.row];
        [[YMDownloadManager shared] deleteDownloadedTracksWithIds:@[t.trackId]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.editing) return;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[YMPlayerManager shared] playQueue:self.tracks startIndex:indexPath.row];
    self.tabBarController.selectedIndex = 1;
}

@end

#pragma mark - 5A. YMThemeSettingsViewController (Нативная таблица настроек UITableViewStyleGrouped)

@interface YMThemeSettingsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation YMThemeSettingsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Оформление";

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [self applyTheme];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToTabBarController:self.tabBarController];
    [self.tableView reloadData];
}

- (UIImage *)previewImageForIconPrefix:(NSString *)prefix isDefault:(BOOL)isDefault {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSArray *candidates = @[
        [NSString stringWithFormat:@"%@@2x.png", prefix],
        [NSString stringWithFormat:@"%@.png", prefix]
    ];
    UIImage *found = nil;
    for (NSString *file in candidates) {
        NSString *fullPath = [bundlePath stringByAppendingPathComponent:file];
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
            found = [UIImage imageWithContentsOfFile:fullPath];
            break;
        }
    }
    if (!found && isDefault) {
        NSString *def2x = [bundlePath stringByAppendingPathComponent:@"Icon@2x.png"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:def2x]) {
            found = [UIImage imageWithContentsOfFile:def2x];
        } else {
            NSString *def1x = [bundlePath stringByAppendingPathComponent:@"Icon.png"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:def1x]) {
                found = [UIImage imageWithContentsOfFile:def1x];
            }
        }
    }
    if (!found) return nil;
    CGSize sz = CGSizeMake(29.0, 29.0);
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0.0);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, sz.width, sz.height) cornerRadius:6.0] addClip];
    [found drawInRect:CGRectMake(0, 0, sz.width, sz.height)];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaled;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 8;
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Набор иконок интерфейса";
    if (section == 1) return @"Акцентный цвет";
    return @"Иконка на домашнем экране";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YMThemeManager *tm = [YMThemeManager shared];

    if (indexPath.section == 0) {
        static NSString *iconSetId = @"IconSetCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:iconSetId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:iconSetId];
        }
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Основные иконки";
            cell.detailTextLabel.text = @"Из ресурсов приложения";
        } else {
            cell.textLabel.text = @"Векторные иконки";
            cell.detailTextLabel.text = @"Отрисованные в коде";
        }
        cell.accessoryType = (tm.currentIconSet == (YMIconSetType)indexPath.row)
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
        return cell;
    }

    if (indexPath.section == 1) {
        static NSString *accentId = @"AccentCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:accentId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:accentId];
        }
        YMAccentColor accent = (YMAccentColor)indexPath.row;
        cell.textLabel.text = [tm accentNameForColor:accent];
        cell.imageView.image = [tm swatchImageForAccent:accent];
        cell.accessoryType = (tm.currentAccentColor == accent)
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
        return cell;
    }

    static NSString *appIconId = @"AppIconCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:appIconId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:appIconId];
    }
    NSArray *titles = @[@"Стандартная", @"Альтернативная 1", @"Альтернативная 2"];
    NSArray *subs = @[@"По умолчанию", @"Второй вариант", @"Третий вариант"];
    NSArray *files = @[@"AppIcon1", @"AppIcon2", @"AppIcon3"];

    cell.textLabel.text = titles[indexPath.row];
    cell.detailTextLabel.text = subs[indexPath.row];
    cell.imageView.image = [self previewImageForIconPrefix:files[indexPath.row] isDefault:(indexPath.row == 0)];

    NSInteger selectedIconIdx = [[NSUserDefaults standardUserDefaults] integerForKey:kYMSelectedIconDefaultsKey];
    cell.accessoryType = (selectedIconIdx == indexPath.row)
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [YMThemeManager shared].currentIconSet = (YMIconSetType)indexPath.row;
    } else if (indexPath.section == 1) {
        [YMThemeManager shared].currentAccentColor = (YMAccentColor)indexPath.row;
    } else if (indexPath.section == 2) {
        [self switchAppIconToIndex:indexPath.row];
    }
}

- (void)switchAppIconToIndex:(NSInteger)index {
    NSArray *prefixes = @[@"AppIcon1", @"AppIcon2", @"AppIcon3"];
    if (index < 0 || index >= (NSInteger)prefixes.count) return;

    NSString *prefix = prefixes[index];
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *src1x = [bundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", prefix]];
    NSString *src2x = [bundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@@2x.png", prefix]];

    if (![fm fileExistsAtPath:src2x] && [fm fileExistsAtPath:src1x]) {
        src2x = src1x;
    } else if (![fm fileExistsAtPath:src1x] && [fm fileExistsAtPath:src2x]) {
        src1x = src2x;
    }

    if (![fm fileExistsAtPath:src1x]) {
        UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Файл не найден"
                                                           message:[NSString stringWithFormat:@"Добавьте файл %@.png в папку Resources проекта.", prefix]
                                                          delegate:nil
                                                 cancelButtonTitle:@"ОК"
                                                 otherButtonTitles:nil];
        [errAlert show];
        return;
    }

    NSString *dst1x = [bundlePath stringByAppendingPathComponent:@"Icon.png"];
    NSString *dst2x = [bundlePath stringByAppendingPathComponent:@"Icon@2x.png"];

    [fm removeItemAtPath:dst1x error:nil];
    [fm removeItemAtPath:dst2x error:nil];
    [fm copyItemAtPath:src1x toPath:dst1x error:nil];
    [fm copyItemAtPath:src2x toPath:dst2x error:nil];

    [fm removeItemAtPath:@"/var/mobile/Library/Caches/com.apple.IconsCache" error:nil];

    [[NSUserDefaults standardUserDefaults] setInteger:index forKey:kYMSelectedIconDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self.tableView reloadData];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Иконка изменена"
                                                    message:@"Для обновления иконки на домашнем экране требуется перезапуск SpringBoard (Respring)."
                                                   delegate:self
                                          cancelButtonTitle:@"Позже"
                                          otherButtonTitles:@"Респринг", nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        system("uicache");
        system("killall -9 SpringBoard");
    }
}

@end

#pragma mark - 5B. YMSettingsViewController (Нативный экран настроек UITableViewStyleGrouped)

@interface YMSettingsViewController ()
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation YMSettingsViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Настройки";

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:YMThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshAccountInfo) name:YMAuthStateChangedNotification object:nil];

    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
    [[YMApiClient shared] fetchAccountInfoWithCompletion:^(NSString *accountName, NSError *error) {
        [self.tableView reloadData];
    }];
}

- (void)refreshAccountInfo {
    [self.tableView reloadData];
}

- (void)applyTheme {
    YMThemeManager *tm = [YMThemeManager shared];
    [tm applyThemeToNavigationController:self.navigationController];
    [tm applyThemeToTabBarController:self.tabBarController];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Аккаунт Яндекс";
    if (section == 1) return @"Интерфейс";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *accCellId = @"AccountValue1Cell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:accCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:accCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        NSString *acc = [YMApiClient shared].accountName;
        if (!acc || acc.length == 0) {
            acc = [[YMApiClient shared] isAuthorized] ? @"Загрузка..." : @"Не авторизован";
        }
        cell.textLabel.text = @"Пользователь";
        cell.detailTextLabel.text = acc;
        return cell;
    }

    if (indexPath.section == 1) {
        static NSString *appCellId = @"AppearanceNavCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:appCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:appCellId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = @"Оформление";
        cell.detailTextLabel.text = [[YMThemeManager shared] currentAppearanceSummary];
        return cell;
    }

    static NSString *logoutCellId = @"LogoutActionCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:logoutCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:logoutCellId];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0];
        cell.textLabel.textColor = [UIColor colorWithRed:0.78 green:0.12 blue:0.12 alpha:1.0];
    }
    cell.textLabel.text = @"Выйти из аккаунта";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        YMThemeSettingsViewController *themeVC = [[YMThemeSettingsViewController alloc] init];
        [self.navigationController pushViewController:themeVC animated:YES];
    } else if (indexPath.section == 2) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Выход из аккаунта"
                                                        message:@"Вы действительно хотите выйти из своего аккаунта Яндекс?"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                              otherButtonTitles:@"Выйти", nil];
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [[YMApiClient shared] logout];
        [self.tableView reloadData];
    }
}

@end