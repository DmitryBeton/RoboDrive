import AppKit
import ImageIO
import UniformTypeIdentifiers

// Vector artwork matching the simulator robot. No external artwork or font dependency.
guard let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
    bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("Cannot create drawing context") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor(calibratedRed: 0.06, green: 0.15, blue: 0.28, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let grid = NSBezierPath()
for value in stride(from: 0, through: 1024, by: 64) {
    grid.move(to: NSPoint(x: value, y: 0)); grid.line(to: NSPoint(x: value, y: 1024))
    grid.move(to: NSPoint(x: 0, y: value)); grid.line(to: NSPoint(x: 1024, y: value))
}
NSColor.white.withAlphaComponent(0.055).setStroke(); grid.lineWidth = 2; grid.stroke()
func block(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill(); NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
block(NSRect(x: 296, y: 231, width: 115, height: 562), radius: 39, color: NSColor(calibratedWhite: 0.17, alpha: 1))
block(NSRect(x: 613, y: 231, width: 115, height: 562), radius: 39, color: NSColor(calibratedWhite: 0.17, alpha: 1))
block(NSRect(x: 337, y: 282, width: 350, height: 460), radius: 104, color: .systemBlue)
block(NSRect(x: 374, y: 628, width: 276, height: 40), radius: 20, color: .white)
NSColor.white.withAlphaComponent(0.15).setFill()
NSBezierPath(ovalIn: NSRect(x: 429, y: 418, width: 166, height: 166)).fill()
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 512, y: 560)); arrow.line(to: NSPoint(x: 564, y: 480)); arrow.line(to: NSPoint(x: 512, y: 498)); arrow.line(to: NSPoint(x: 460, y: 480)); arrow.close()
NSColor.white.setFill(); arrow.fill()
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "RoboDrive/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let cgImage = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("Cannot create icon output") }
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write icon") }
