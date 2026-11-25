import SwiftUI
import TimingCore

extension Color {
    init(_ rgb: HeatPalette.RGB) { self.init(red: rgb.red, green: rgb.green, blue: rgb.blue) }

    /// Accent behind white text and for controls. At least 4.5:1 against white.
    static let accentFill = Color(red: 0.76, green: 0.25, blue: 0.05)
    /// Accent on the black and glass surfaces iOS draws timers on.
    static let accentBright = Color(red: 1, green: 0.6, blue: 0.32)
}

struct HeatGradient: View {
    let fractionLeft: Double

    var body: some View {
        let heat = HeatPalette(fractionLeft: fractionLeft)
        LinearGradient(colors: [Color(heat.deep), Color(heat.bright)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
