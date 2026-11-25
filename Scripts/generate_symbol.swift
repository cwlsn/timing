// The app icon's timer as a one-color symbol for widgets and Control Center.
// Run: swift Scripts/generate_symbol.swift Shared/Symbols.xcassets/CatTimer.symbolset/CatTimer.svg
import CoreGraphics
import Foundation

func point(_ degrees: Double, _ radius: Double, side: Double = 1) -> CGPoint {
    CGPoint(x: side * radius * cos(degrees * .pi / 180), y: -radius * sin(degrees * .pi / 180))
}
var shape: CGPath = CGPath(ellipseIn: CGRect(x: -272, y: -272, width: 544, height: 544), transform: nil)
for side in [-1.0, 1.0] {
    let ear = CGMutablePath()
    ear.addLines(between: [point(32, 232, side: side), point(53, 360, side: side), point(74, 232, side: side)])
    ear.closeSubpath()
    shape = shape.union(ear).union(ear.copy(strokingWithWidth: 44, lineCap: .round, lineJoin: .round, miterLimit: 10))
}
let pointer = CGMutablePath()
pointer.addLines(between: [.zero, point(-30, 168)])
// Heavier than the icon's, to survive small sizes.
shape = shape.subtracting(pointer.copy(strokingWithWidth: 64, lineCap: .round, lineJoin: .round, miterLimit: 10))
shape = shape.subtracting(CGPath(ellipseIn: CGRect(x: -62, y: -62, width: 124, height: 124), transform: nil))

let scale = 0.175, box = shape.boundingBoxOfPath
// Centered between the template's small baseline (696) and capline (625.541).
var place = CGAffineTransform(translationX: 0, y: 660.77).scaledBy(x: scale, y: scale).translatedBy(x: -box.midX, y: -box.midY)
var d = ""
func f(_ p: CGPoint) -> String { String(format: "%.3f %.3f", p.x, p.y) }
shape.copy(using: &place)!.applyWithBlock { element in
    let e = element.pointee
    switch e.type {
    case .moveToPoint: d += "M\(f(e.points[0]))"
    case .addLineToPoint: d += "L\(f(e.points[0]))"
    case .addQuadCurveToPoint: d += "Q\(f(e.points[0])) \(f(e.points[1]))"
    case .addCurveToPoint: d += "C\(f(e.points[0])) \(f(e.points[1])) \(f(e.points[2]))"
    case .closeSubpath: d += "Z"
    @unknown default: break
    }
}
let half = box.width * scale / 2 + 8
// The same outline at the three weights iOS blends between.
let weights = [("Ultralight", 560.0), ("Regular", 1400.0), ("Black", 2850.0)]
let margins = weights.map { name, x in
    """
      <line id="left-margin-\(name)-S" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(x - half)" x2="\(x - half)" y1="600.785" y2="720.121"/>
      <line id="right-margin-\(name)-S" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(x + half)" x2="\(x + half)" y1="600.785" y2="720.121"/>
    """
}.joined(separator: "\n")
let glyphs = weights.map { name, x in
    "  <g id=\"\(name)-S\" transform=\"matrix(1 0 0 1 \(x) 0)\"><path d=\"\(d)\"/></g>"
}.joined(separator: "\n")
func line(_ id: String, _ y: Double) -> String { "  <line id=\"\(id)\" style=\"fill:none;stroke:#27AAE1;stroke-width:0.5;\" x1=\"263\" x2=\"3036\" y1=\"\(y)\" y2=\"\(y)\"/>" }
let rows = [("S", 696.0, 625.541), ("M", 1126, 1055.54), ("L", 1556, 1485.54)]
    .flatMap { [line("Baseline-\($0.0)", $0.1), line("Capline-\($0.0)", $0.2)] }.joined(separator: "\n")
let svg = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <g id="Notes">
  <rect id="artboard" style="fill:white;opacity:1" width="3300" height="2200" x="0" y="0"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
 </g>
 <g id="Guides">
\(rows)
\(margins)
 </g>
 <g id="Symbols">
\(glyphs)
 </g>
</svg>
"""
try svg.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
