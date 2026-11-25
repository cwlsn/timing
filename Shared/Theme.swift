import SwiftUI
import TimingCore

extension Color {
    init(_ rgb: SpectrumPalette.RGB) { self.init(red: rgb.red, green: rgb.green, blue: rgb.blue) }

    /// Accent behind white text and for controls. At least 4.5:1 against white.
    static let accentFill = Color(red: 0.33, green: 0.27, blue: 0.92)
    /// Accent on the black and glass surfaces iOS draws timers on.
    static let accentBright = Color(red: 0.62, green: 0.58, blue: 1)
}

struct SpectrumGradient: View {
    let fractionLeft: Double

    var body: some View {
        let spectrum = SpectrumPalette(fractionLeft: fractionLeft)
        LinearGradient(colors: [Color(spectrum.deep), Color(spectrum.bright)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension TimerRun {
    var isLive: Bool { if case .paused = phase { false } else { true } }
    var isRinging: Bool { phase == .ringing }
    var isPaused: Bool { !isLive }
}
