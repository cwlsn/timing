// Run: swift Scripts/readme_image.swift <input.png> <output.png> <width> <corner radius as a fraction of width>
// Scales an image for the README, rounds its corners and draws a hairline edge so light screens stand out on white.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 5, let width = Double(arguments[3]), let corner = Double(arguments[4]),
      let source = NSImage(contentsOfFile: arguments[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write(Data("usage: readme_image.swift <input.png> <output.png> <width> <corner fraction>\n".utf8))
    exit(1)
}

let height = (width * Double(source.height) / Double(source.width)).rounded()
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.interpolationQuality = .high
let bounds = CGRect(x: 0, y: 0, width: width, height: height)
let radius = width * corner
let shape = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
context.addPath(shape)
context.clip()
context.draw(source, in: bounds)
// A neutral edge reads on both GitHub themes without framing dark screens in a bright line.
let inset = bounds.insetBy(dx: 0.5, dy: 0.5)
context.addPath(CGPath(roundedRect: inset, cornerWidth: radius - 0.5, cornerHeight: radius - 0.5, transform: nil))
context.setStrokeColor(CGColor(colorSpace: space, components: [0.5, 0.5, 0.5, 0.35])!)
context.setLineWidth(1)
context.strokePath()

let data = NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
try data.write(to: URL(filePath: arguments[2]))
