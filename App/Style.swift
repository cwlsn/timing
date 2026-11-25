import SwiftUI
import TimingCore

extension Color {
    /// Readable as small text in both appearances.
    static let accentText = Color(uiColor: UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(red: 0.68, green: 0.64, blue: 1, alpha: 1) : UIColor(red: 0.30, green: 0.24, blue: 0.85, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor {
        $0.userInterfaceStyle == .dark ? UIColor(white: 0.04, alpha: 1) : UIColor(white: 0.99, alpha: 1)
    })
    static let magenta = Color(red: 0.85, green: 0.08, blue: 0.62)
    /// Neutral fill for chips and tiles.
    static let chip = Color.primary.opacity(0.06)
    static let hairline = Color.primary.opacity(0.10)
    /// Secondary text with at least 4.5:1 contrast on the canvas.
    static let quiet = Color(uiColor: UIColor {
        UIColor(white: $0.userInterfaceStyle == .dark ? 0.62 : 0.40, alpha: 1)
    })
}

struct Chip<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 6) { content }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.accentText : Color.primary)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(isSelected ? Color.accentFill.opacity(0.16) : Color.chip, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentFill.opacity(0.6) : Color.hairline, lineWidth: 1)
            }
            .contentShape(.rect)
    }
}

/// Dips under the finger and springs back.
struct SpringyButtonStyle: ButtonStyle {
    var scale = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(duration: 0.28, bounce: 0.5), value: configuration.isPressed)
    }
}

/// A kitchen timer with cat ears: the app icon, alive. The pointer winds into place.
struct TimerMark: View {
    @State private var isSet = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ear(-1)
            ear(1)
            Circle().fill(Color.accentFill).frame(width: 110)
            Circle()
                .trim(from: 0, to: isSet ? 1 / 3 : 0)
                .stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 39))
                .frame(width: 39, height: 39)
                .rotationEffect(.degrees(-90))
            Path { path in
                path.move(to: CGPoint(x: 80, y: 80))
                path.addLine(to: CGPoint(x: 80, y: 46))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 11, lineCap: .round))
            .rotationEffect(.degrees(isSet ? 120 : 0))
            Circle().fill(.white).frame(width: 19)
        }
        .frame(width: 160, height: 160)
        .animation(reduceMotion ? nil : .spring(duration: 1.1, bounce: 0.2), value: isSet)
        .onAppear { isSet = true }
        .accessibilityHidden(true)
    }

    private func ear(_ side: CGFloat) -> some View {
        let shape = Path { path in
            func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
                CGPoint(x: 80 + side * radius * cos(degrees * .pi / 180), y: 80 - radius * sin(degrees * .pi / 180))
            }
            path.addLines([point(32, 47), point(53, 73), point(74, 47)])
            path.closeSubpath()
        }
        return ZStack {
            shape.fill(Color.accentFill)
            shape.stroke(Color.accentFill, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
        }
    }
}
