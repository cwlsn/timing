// Run: swift Scripts/generate_icon.swift Resources/Assets.xcassets/AppIcon.appiconset/icon.png
import AppKit

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let c = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: Double, _ g: Double, _ b: Double) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, 1])! }
let purple = CGGradient(colorsSpace: space, colors: [color(0.45, 0.48, 1), color(0.36, 0.16, 0.80)] as CFArray, locations: nil)!
c.drawLinearGradient(purple, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
// A kitchen timer: a face with cat ears, a wedge of time left, and a pointer.
let center = CGPoint(x: 512, y: 478)
func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
c.setFillColor(color(1, 1, 1))
c.fillEllipse(in: CGRect(x: center.x - 272, y: center.y - 272, width: 544, height: 544))
// Each ear is a triangle rooted inside the face, its corners rounded by the stroke.
c.setLineCap(.round)
c.setLineJoin(.round)
c.setLineWidth(44)
c.setStrokeColor(color(1, 1, 1))
for side in [-1.0, 1.0] {
    func point(_ degrees: Double, _ radius: Double) -> CGPoint {
        CGPoint(x: center.x + side * radius * cos(radians(degrees)), y: center.y + radius * sin(radians(degrees)))
    }
    c.move(to: point(32, 232))
    c.addLine(to: point(53, 360))
    c.addLine(to: point(74, 232))
    c.closePath()
    c.drawPath(using: .fillStroke)
}
// The wedge is the time left, from the top around to the pointer.
c.setFillColor(color(0.84, 0.80, 1))
c.move(to: center)
c.addArc(center: center, radius: 196, startAngle: radians(90), endAngle: radians(-30), clockwise: true)
c.closePath()
c.fillPath()
c.setLineWidth(54)
c.setStrokeColor(color(0.33, 0.27, 0.92))
c.move(to: center)
c.addLine(to: CGPoint(x: center.x + 168 * cos(radians(-30)), y: center.y + 168 * sin(radians(-30))))
c.strokePath()
c.setFillColor(color(0.33, 0.27, 0.92))
c.fillEllipse(in: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))
let data = NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
try data.write(to: URL(filePath: CommandLine.arguments[1]))
