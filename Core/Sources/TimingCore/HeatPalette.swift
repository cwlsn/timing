import Foundation

/// Cool when there is long to go, warming to ember as a timer nears zero. Dark enough for white body text.
public struct HeatPalette: Hashable, Sendable {
    public struct RGB: Hashable, Sendable {
        public let red, green, blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            (self.red, self.green, self.blue) = (red, green, blue)
        }

        func mixed(with other: RGB, by t: Double) -> RGB {
            RGB(red + (other.red - red) * t, green + (other.green - green) * t, blue + (other.blue - blue) * t)
        }

        /// WCAG contrast ratio against white.
        var contrastWithWhite: Double {
            func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 1.05 / (0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue) + 0.05)
        }
    }

    public let deep, bright: RGB

    private static let keys: [(left: Double, deep: RGB, bright: RGB)] = [
        (0, .init(0.60, 0.09, 0.07), .init(0.80, 0.21, 0.07)),
        (0.25, .init(0.62, 0.22, 0.05), .init(0.72, 0.34, 0.03)),
        (0.55, .init(0.46, 0.30, 0.22), .init(0.60, 0.38, 0.12)),
        (1, .init(0.22, 0.31, 0.45), .init(0.30, 0.42, 0.56)),
    ]

    public init(fractionLeft: Double) {
        let left = min(max(fractionLeft.isNaN ? 0 : fractionLeft, 0), 1)
        let upper = Self.keys.firstIndex { $0.left >= left } ?? Self.keys.count - 1
        let to = Self.keys[upper], from = Self.keys[max(0, upper - 1)]
        let t = to.left > from.left ? (left - from.left) / (to.left - from.left) : 0
        deep = from.deep.mixed(with: to.deep, by: t)
        bright = from.bright.mixed(with: to.bright, by: t)
    }
}
