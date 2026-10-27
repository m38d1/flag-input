import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

let background = NSBezierPath(
    roundedRect: NSRect(x: 84, y: 84, width: 856, height: 856),
    xRadius: 198,
    yRadius: 198
)
NSGradient(colors: [color(0x3D5BFF), color(0x7A4DFF)])!.draw(in: background, angle: -90)

let pole = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: 46, height: 500),
    xRadius: 23,
    yRadius: 23
)

let banner = NSBezierPath()
banner.move(to: NSPoint(x: 46, y: 462))
banner.curve(
    to: NSPoint(x: 430, y: 444),
    controlPoint1: NSPoint(x: 164, y: 506),
    controlPoint2: NSPoint(x: 296, y: 490)
)
banner.curve(
    to: NSPoint(x: 430, y: 252),
    controlPoint1: NSPoint(x: 466, y: 404),
    controlPoint2: NSPoint(x: 466, y: 292)
)
banner.curve(
    to: NSPoint(x: 46, y: 216),
    controlPoint1: NSPoint(x: 296, y: 244),
    controlPoint2: NSPoint(x: 164, y: 264)
)
banner.close()

let glyph = NSBezierPath()
glyph.append(pole)
glyph.append(banner)

let bounds = glyph.bounds
let targetSize: CGFloat = 500
let scale = min(targetSize / bounds.width, targetSize / bounds.height)

context.saveGState()
context.translateBy(
    x: (canvas - bounds.width * scale) / 2 - bounds.minX * scale,
    y: (canvas - bounds.height * scale) / 2 - bounds.minY * scale
)
context.scaleBy(x: scale, y: scale)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 36 / scale
shadow.shadowOffset = NSSize(width: 0, height: -14 / scale)
shadow.set()

NSColor.white.setFill()
glyph.fill()
NSShadow().set()

context.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("could not render icon")
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png")
try png.write(to: output)
print("wrote \(output.path)")
