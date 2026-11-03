import AppKit
import CoreText

struct Palette {
    var background: NSColor
    var glyph: NSColor
    var track: NSColor
    var fill: NSColor
}

func color(hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func bitmap(width: Int, height: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    return rep
}

func withContext(_ rep: NSBitmapImageRep, _ draw: (CGContext) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: rep)!
    graphics.imageInterpolation = .high
    NSGraphicsContext.current = graphics
    draw(graphics.cgContext)
    NSGraphicsContext.restoreGraphicsState()
}

func fill(_ rect: NSRect, _ color: NSColor) {
    color.setFill()
    rect.fill()
}

func rounded(_ rect: NSRect, radius: CGFloat, _ color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func drawGlyph(in context: CGContext, text: String, font: NSFont, color: NSColor, center: CGPoint) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: color
    ]))
    let bounds = CTLineGetImageBounds(line, context)
    context.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, context)
}

func drawMark(in context: CGContext, canvas: CGSize, palette: Palette, fullBleed: Bool) {
    let side = min(canvas.width, canvas.height)
    let origin = CGPoint(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2)
    let bounds = CGRect(origin: origin, size: CGSize(width: side, height: side))

    if fullBleed {
        fill(NSRect(origin: .zero, size: canvas), palette.background)
    } else {
        fill(NSRect(origin: .zero, size: canvas), .clear)
        let inset = side * 0.04
        let seal = bounds.insetBy(dx: inset, dy: inset)
        rounded(NSRect(x: seal.minX, y: seal.minY, width: seal.width, height: seal.height), radius: seal.width * 0.24, palette.background)
    }

    let field = fullBleed ? bounds : bounds.insetBy(dx: side * 0.04, dy: side * 0.04)
    let barHeight = field.height * 0.072
    let barWidth = field.width * 0.62
    let barX = field.midX - barWidth / 2
    let barY = field.minY + field.height * 0.145
    let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
    rounded(NSRect(x: barRect.minX, y: barRect.minY, width: barRect.width, height: barRect.height), radius: barHeight / 2, palette.track)

    let fillWidth = barWidth * 0.64
    rounded(
        NSRect(x: barRect.minX, y: barRect.minY, width: fillWidth, height: barHeight),
        radius: barHeight / 2,
        palette.fill
    )

    let fontSize = field.width * 0.52
    let font = NSFont(name: "Georgia-Bold", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize, weight: .bold)
    let glyphCenter = CGPoint(x: field.midX, y: field.midY + field.height * 0.055)
    drawGlyph(in: context, text: "W", font: font, color: palette.glyph, center: glyphCenter)
}

func save(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("png failed: \(path)\n", stderr)
        exit(1)
    }
    try! data.write(to: URL(fileURLWithPath: path))
    print(path)
}

func renderSquare(size: Int, palette: Palette, fullBleed: Bool) -> NSBitmapImageRep {
    let rep = bitmap(width: size, height: size)
    withContext(rep) { context in
        drawMark(in: context, canvas: CGSize(width: size, height: size), palette: palette, fullBleed: fullBleed)
    }
    return rep
}

let light = Palette(
    background: color(hex: 0x9E3D22),
    glyph: color(hex: 0xFFF8F2),
    track: color(hex: 0x7A2E18),
    fill: color(hex: 0xFFF8F2)
)
let dark = Palette(
    background: color(hex: 0xE28A5A),
    glyph: color(hex: 0x1C1916),
    track: color(hex: 0xC46A38),
    fill: color(hex: 0x1C1916)
)
let tinted = Palette(
    background: color(hex: 0x8A8A8A),
    glyph: .white,
    track: color(hex: 0x5C5C5C),
    fill: .white
)

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let iconDir = "\(root)/WishSaver/Resource/Assets.xcassets/AppIcon.appiconset"
let sealDir = "\(root)/WishSaver/Resource/Assets.xcassets/LaunchSeal.imageset"
let markDir = "\(root)/WishSaver/Resource/Assets.xcassets/WishAppIcon.imageset"

save(renderSquare(size: 1024, palette: light, fullBleed: true), to: "\(iconDir)/AppIcon.png")
save(renderSquare(size: 1024, palette: dark, fullBleed: true), to: "\(iconDir)/AppIconDark.png")
save(renderSquare(size: 1024, palette: tinted, fullBleed: true), to: "\(iconDir)/AppIconTinted.png")
save(renderSquare(size: 1024, palette: light, fullBleed: true), to: "\(markDir)/WishAppIcon.png")
save(renderSquare(size: 1024, palette: dark, fullBleed: true), to: "\(markDir)/WishAppIconDark.png")
save(renderSquare(size: 1024, palette: light, fullBleed: false), to: "\(sealDir)/LaunchSeal.png")
save(renderSquare(size: 1024, palette: dark, fullBleed: false), to: "\(sealDir)/LaunchSealDark.png")

func renderLaunchPreview(palette: Palette, paper: NSColor, ink: NSColor, secondary: NSColor, seal: NSBitmapImageRep) -> NSBitmapImageRep {
    let width = 1179
    let height = 2556
    let scale: CGFloat = 3
    let rep = bitmap(width: width, height: height)
    withContext(rep) { _ in
        fill(NSRect(x: 0, y: 0, width: width, height: height), paper)
        guard let sealImage = NSImage(data: seal.representation(using: .png, properties: [:])!) else { return }
        let sealSide: CGFloat = 112 * scale
        let titleFont = NSFont(name: "Georgia-Bold", size: 34 * scale)!
        let subtitleFont = NSFont(name: "Avenir-Medium", size: 16 * scale)!
        let title = "Wish Saver" as NSString
        let subtitle = "Turn a wish into a daily amount" as NSString
        let titleSize = title.size(withAttributes: [.font: titleFont])
        let subtitleSize = subtitle.size(withAttributes: [.font: subtitleFont])
        let gap: CGFloat = 18 * scale
        let textGap: CGFloat = 8 * scale
        let block = sealSide + gap + titleSize.height + textGap + subtitleSize.height
        let top = (CGFloat(height) + block) / 2 + 28 * scale
        let sealRect = NSRect(x: (CGFloat(width) - sealSide) / 2, y: top - sealSide, width: sealSide, height: sealSide)
        sealImage.draw(in: sealRect, from: .zero, operation: .sourceOver, fraction: 1)

        let titleY = sealRect.minY - gap - titleSize.height
        title.draw(
            in: NSRect(x: 0, y: titleY, width: CGFloat(width), height: titleSize.height),
            withAttributes: [
                .font: titleFont,
                .foregroundColor: ink,
                .paragraphStyle: centered()
            ]
        )
        subtitle.draw(
            in: NSRect(x: 0, y: titleY - textGap - subtitleSize.height, width: CGFloat(width), height: subtitleSize.height),
            withAttributes: [
                .font: subtitleFont,
                .foregroundColor: secondary,
                .paragraphStyle: centered()
            ]
        )
    }
    return rep
}

func centered() -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    return style
}

let lightSeal = renderSquare(size: 1024, palette: light, fullBleed: false)
let darkSeal = renderSquare(size: 1024, palette: dark, fullBleed: false)
save(
    renderLaunchPreview(
        palette: light,
        paper: color(hex: 0xF4EFE6),
        ink: color(hex: 0x1C1916),
        secondary: color(hex: 0x5E564E),
        seal: lightSeal
    ),
    to: "/tmp/launch-light.png"
)
save(
    renderLaunchPreview(
        palette: dark,
        paper: color(hex: 0x14110F),
        ink: color(hex: 0xF6F1EA),
        secondary: color(hex: 0xC8BBAE),
        seal: darkSeal
    ),
    to: "/tmp/launch-dark.png"
)
