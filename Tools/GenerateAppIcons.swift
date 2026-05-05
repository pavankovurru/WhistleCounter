import AppKit
import CoreGraphics
import Foundation

struct RGBA {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat
    var a: CGFloat = 1

    init(hex: UInt, alpha: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xff) / 255
        g = CGFloat((hex >> 8) & 0xff) / 255
        b = CGFloat(hex & 0xff) / 255
        a = alpha
    }

    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

    func opacity(_ value: CGFloat) -> RGBA {
        RGBA(r, g, b, a * value)
    }

    func mixed(with other: RGBA, amount: CGFloat) -> RGBA {
        RGBA(
            r + (other.r - r) * amount,
            g + (other.g - g) * amount,
            b + (other.b - b) * amount,
            a + (other.a - a) * amount
        )
    }

    func darkened(_ amount: CGFloat) -> RGBA {
        mixed(with: RGBA(0, 0, 0), amount: amount)
    }

    func lightened(_ amount: CGFloat) -> RGBA {
        mixed(with: RGBA(1, 1, 1), amount: amount)
    }
}

struct IconPalette {
    var backgroundTop: RGBA
    var backgroundBottom: RGBA
    var glow: RGBA
    var body: RGBA
    var belly: RGBA
    var shadow: RGBA
    var cheek: RGBA
}

let orange = RGBA(hex: 0xFF6B35)
let sunny = RGBA(hex: 0xFFD93D)
let cream = RGBA(hex: 0xFFF8F0)
let charcoal = RGBA(hex: 0x2D2D2D)
let mint = RGBA(hex: 0x6BCB77)
let navy = RGBA(hex: 0x1A1A2E)

let variants: [(String, IconPalette)] = [
    (
        "WhistleCounterIconLight.png",
        IconPalette(
            backgroundTop: cream,
            backgroundBottom: RGBA(hex: 0xFFE189),
            glow: sunny,
            body: orange,
            belly: sunny,
            shadow: RGBA(hex: 0x9A341B),
            cheek: RGBA(1.0, 0.41, 0.51)
        )
    ),
    (
        "WhistleCounterIconDark.png",
        IconPalette(
            backgroundTop: RGBA(hex: 0x13233F),
            backgroundBottom: navy,
            glow: RGBA(hex: 0xE8A045),
            body: RGBA(hex: 0xFF7A3D),
            belly: RGBA(hex: 0xFFD86B),
            shadow: RGBA(hex: 0x120C16),
            cheek: RGBA(hex: 0xFF8AA8)
        )
    ),
    (
        "WhistleCounterIconTinted.png",
        IconPalette(
            backgroundTop: RGBA(hex: 0xD7FFF0),
            backgroundBottom: RGBA(hex: 0x58D5BF),
            glow: RGBA(hex: 0xFFF1A6),
            body: RGBA(hex: 0xFF8A4C),
            belly: RGBA(hex: 0xFFF5B8),
            shadow: RGBA(hex: 0x176B63),
            cheek: RGBA(hex: 0xFF8AA8)
        )
    )
]

let outputDir = URL(fileURLWithPath: "/Users/pavankovurru/WhistleCounter/WhistleCounter/Assets.xcassets/AppIcon.appiconset")
let size = 1024
let mascotScale: CGFloat = 4.36
let mascotOrigin = CGPoint(x: (CGFloat(size) - 200 * mascotScale) / 2, y: 4)

func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: mascotOrigin.x + x * mascotScale, y: mascotOrigin.y + y * mascotScale)
}

func rect(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
    CGRect(
        x: mascotOrigin.x + (centerX - width / 2) * mascotScale,
        y: mascotOrigin.y + (centerY - height / 2) * mascotScale,
        width: width * mascotScale,
        height: height * mascotScale
    )
}

func roundedRect(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> CGPath {
    CGPath(
        roundedRect: rect(centerX: centerX, centerY: centerY, width: width, height: height),
        cornerWidth: radius * mascotScale,
        cornerHeight: radius * mascotScale,
        transform: nil
    )
}

func ellipse(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
    CGPath(ellipseIn: rect(centerX: centerX, centerY: centerY, width: width, height: height), transform: nil)
}

func bodyPath() -> CGPath {
    let r = CGRect(
        x: mascotOrigin.x + 25 * mascotScale,
        y: mascotOrigin.y + 58 * mascotScale,
        width: 150 * mascotScale,
        height: 130 * mascotScale
    )
    let w = r.width
    let h = r.height
    let path = CGMutablePath()
    path.move(to: CGPoint(x: r.minX + w * 0.50, y: r.minY))
    path.addCurve(
        to: CGPoint(x: r.maxX, y: r.minY + h * 0.48),
        control1: CGPoint(x: r.minX + w * 0.82, y: r.minY),
        control2: CGPoint(x: r.maxX, y: r.minY + h * 0.18)
    )
    path.addCurve(
        to: CGPoint(x: r.minX + w * 0.86, y: r.maxY),
        control1: CGPoint(x: r.maxX, y: r.minY + h * 0.78),
        control2: CGPoint(x: r.minX + w * 0.98, y: r.maxY)
    )
    path.addLine(to: CGPoint(x: r.minX + w * 0.14, y: r.maxY))
    path.addCurve(
        to: CGPoint(x: r.minX, y: r.minY + h * 0.48),
        control1: CGPoint(x: r.minX + w * 0.02, y: r.maxY),
        control2: CGPoint(x: r.minX, y: r.minY + h * 0.78)
    )
    path.addCurve(
        to: CGPoint(x: r.minX + w * 0.50, y: r.minY),
        control1: CGPoint(x: r.minX, y: r.minY + h * 0.18),
        control2: CGPoint(x: r.minX + w * 0.18, y: r.minY)
    )
    path.closeSubpath()
    return path
}

func handlePath(left: Bool) -> CGPath {
    let r = rect(centerX: left ? 22 : 178, centerY: 123.8, width: 22, height: 38)
    let path = CGMutablePath()
    if left {
        path.move(to: CGPoint(x: r.maxX, y: r.minY))
        path.addCurve(to: CGPoint(x: r.minX, y: r.midY), control1: CGPoint(x: r.minX, y: r.minY), control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.20))
        path.addCurve(to: CGPoint(x: r.maxX, y: r.maxY), control1: CGPoint(x: r.minX, y: r.maxY - r.height * 0.20), control2: CGPoint(x: r.minX, y: r.maxY))
    } else {
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addCurve(to: CGPoint(x: r.maxX, y: r.midY), control1: CGPoint(x: r.maxX, y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + r.height * 0.20))
        path.addCurve(to: CGPoint(x: r.minX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.20), control2: CGPoint(x: r.maxX, y: r.maxY))
    }
    path.closeSubpath()
    return path
}

func smilePath() -> CGPath {
    let r = rect(centerX: 100, centerY: 143, width: 28, height: 14)
    let path = CGMutablePath()
    path.move(to: CGPoint(x: r.minX, y: r.minY))
    path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
    path.addCurve(to: CGPoint(x: r.minX, y: r.minY), control1: CGPoint(x: r.maxX, y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY))
    path.closeSubpath()
    return path
}

func fillLinear(_ ctx: CGContext, path: CGPath, colors: [RGBA], start: CGPoint, end: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cg) as CFArray, locations: nil)!
    ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    ctx.restoreGState()
}

func fillRadial(_ ctx: CGContext, path: CGPath, colors: [RGBA], locations: [CGFloat]? = nil, center: CGPoint, radius: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cg) as CFArray, locations: locations)!
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    ctx.restoreGState()
}

func fill(_ ctx: CGContext, _ path: CGPath, _ color: RGBA) {
    ctx.addPath(path)
    ctx.setFillColor(color.cg)
    ctx.fillPath()
}

func drawBackground(_ ctx: CGContext, palette: IconPalette) {
    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    fillLinear(ctx, path: CGPath(rect: canvas, transform: nil), colors: [palette.backgroundTop, palette.backgroundBottom], start: .zero, end: CGPoint(x: 1024, y: 1024))
    fill(ctx, CGPath(ellipseIn: CGRect(x: -96, y: -80, width: 560, height: 560), transform: nil), palette.glow.opacity(0.44))
    fill(ctx, CGPath(ellipseIn: CGRect(x: 610, y: 90, width: 340, height: 340), transform: nil), mint.opacity(0.14))
}

func drawWhistle(_ ctx: CGContext, palette: IconPalette) {
    let body = palette.body
    fill(ctx, roundedRect(centerX: 100, centerY: 77, width: 18, height: 22, radius: 3), body.darkened(0.45))
    fill(ctx, roundedRect(centerX: 100, centerY: 91, width: 40, height: 10, radius: 4), body.darkened(0.35))
    fillLinear(
        ctx,
        path: ellipse(centerX: 100, centerY: 59, width: 40, height: 22),
        colors: [body.darkened(0.25), body.darkened(0.50)],
        start: point(100, 48),
        end: point(100, 70)
    )
    fill(ctx, roundedRect(centerX: 100, centerY: 44, width: 10, height: 8, radius: 3), body.darkened(0.55))
}

func drawMascot(_ ctx: CGContext, palette: IconPalette) {
    let body = palette.body

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 28), blur: 36, color: palette.shadow.opacity(0.24).cg)
    drawWhistle(ctx, palette: palette)
    fill(ctx, handlePath(left: true), body.darkened(0.22))
    fill(ctx, handlePath(left: false), body.darkened(0.22))
    ctx.restoreGState()

    let mainBody = bodyPath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 28), blur: 42, color: palette.shadow.opacity(0.34).cg)
    fillRadial(
        ctx,
        path: mainBody,
        colors: [body.lightened(0.18), body.lightened(0.08), body, body.darkened(0.12)],
        locations: [0, 0.24, 0.62, 1],
        center: point(70, 90),
        radius: 650
    )
    ctx.restoreGState()

    fill(ctx, ellipse(centerX: 100, centerY: 137.5, width: 117, height: 60), palette.belly.opacity(0.92))

    fill(ctx, ellipse(centerX: 78, centerY: 111.3, width: 20, height: 22), RGBA(1, 1, 1))
    fill(ctx, ellipse(centerX: 122, centerY: 111.3, width: 20, height: 22), RGBA(1, 1, 1))
    fill(ctx, ellipse(centerX: 78, centerY: 112.8, width: 11, height: 13), charcoal)
    fill(ctx, ellipse(centerX: 122, centerY: 112.8, width: 11, height: 13), charcoal)
    fill(ctx, ellipse(centerX: 78.9, centerY: 107.8, width: 3.4, height: 3.4), RGBA(1, 1, 1))
    fill(ctx, ellipse(centerX: 122.9, centerY: 107.8, width: 3.4, height: 3.4), RGBA(1, 1, 1))

    fill(ctx, smilePath(), charcoal)
    fill(ctx, ellipse(centerX: 66, centerY: 129.5, width: 14, height: 8), palette.cheek.opacity(0.65))
    fill(ctx, ellipse(centerX: 134, centerY: 129.5, width: 14, height: 8), palette.cheek.opacity(0.65))

    fill(ctx, ellipse(centerX: 100, centerY: 189, width: 141, height: 14), body.darkened(0.22))
    fill(ctx, ellipse(centerX: 82, centerY: 189, width: 28, height: 14), body.darkened(0.30))
    fill(ctx, ellipse(centerX: 118, centerY: 189, width: 28, height: 14), body.darkened(0.30))
}

func renderIcon(named filename: String, palette: IconPalette) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let ctx = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext else {
        throw NSError(domain: "Icon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    ctx.interpolationQuality = .high
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: 1, y: -1)
    drawBackground(ctx, palette: palette)
    drawMascot(ctx, palette: palette)
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Icon", code: 2)
    }
    try png.write(to: outputDir.appendingPathComponent(filename))
}

for variant in variants {
    try renderIcon(named: variant.0, palette: variant.1)
}
