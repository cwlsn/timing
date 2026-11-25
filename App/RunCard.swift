import SwiftUI
import TimingCore

/// A countdown readable from across the kitchen. It grows its buttons when it rings.
struct RunCard: View {
    let run: TimerRun
    /// Whether it has a whole row, or shares one.
    let isFull: Bool
    let model: TimerModel
    let perform: (@escaping () async throws -> Void) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 48

    var body: some View {
        let beside = isFull && !typeSize.isAccessibilitySize
        let layout = beside ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
        VStack(alignment: .leading, spacing: 16) {
            layout {
                details.frame(maxWidth: .infinity, alignment: .leading)
                if !run.isRinging {
                    HStack(spacing: 10) {
                        control(run.isPaused ? "play.fill" : "pause.fill", run.isPaused ? "Resume" : "Pause", fills: !beside) {
                            if run.isPaused { try await model.resume(run.id) } else { try await model.pause(run.id) }
                        }
                        control("xmark", "Stop", fills: !beside) { try await model.stop(run) }
                    }
                }
            }
            if run.isRinging { ringButtons }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background { RunGlow(run: run) }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .contentShape(.rect)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: run.isPaused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-\(run.timer.displayLabel)")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(run.timer.displayIcon) \(run.timer.displayLabel)")
                .font(.headline)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                .accessibilityLabel(run.timer.displayLabel)
            Ticking(isActive: run.isLive && !run.isRinging) { now in
                let text = DurationText.countdown(run.remaining(at: now))
                Text(text)
                    .font(.system(size: min(timeSize, 84), weight: .medium).monospacedDigit())
                    .tracking(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: text)
                    .opacity(run.isPaused ? 0.8 : 1)
                    .accessibilityIdentifier("countdown-\(run.timer.displayLabel)")
            }
            Text(status).font(.footnote).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var status: String {
        switch run.phase {
        case .running(let endsAt): "Ends at \(endsAt.formatted(date: .omitted, time: .shortened))"
        case .paused: "Paused"
        case .ringing: "Time's up"
        }
    }

    private var ringButtons: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return layout {
            wide("Add \(run.timer.addMinutes)m") { try await model.addTime(run) }
            wide("Repeat") { try await model.repeat(run) }
            wide("Stop", isPrimary: true) { try await model.stop(run) }
        }
    }

    /// A circle beside the time, or stretched across a half-width card.
    private func control(_ symbol: String, _ name: String, fills: Bool, _ work: @escaping () async throws -> Void) -> some View {
        Button { perform(work) } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: fills ? .infinity : 52)
                .frame(width: fills ? nil : 52, height: fills ? 48 : 52)
                .background(.black.opacity(0.22), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(SpringyButtonStyle())
        .accessibilityLabel("\(name) \(run.timer.displayLabel)")
    }

    private func wide(_ name: String, isPrimary: Bool = false, _ work: @escaping () async throws -> Void) -> some View {
        Button { perform(work) } label: {
            Text(name)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 60)
                .foregroundStyle(isPrimary ? Color.accentFill : .white)
                .background(isPrimary ? Color.white : .black.opacity(0.22), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(SpringyButtonStyle(scale: 0.95))
        .accessibilityLabel("\(name) \(run.timer.displayLabel)")
    }
}

/// Color filling the card. It drains as time passes and glows slowly while ringing.
private struct RunGlow: View {
    let run: TimerRun
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if run.isRinging {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                    let wave = reduceMotion ? 0 : (sin(context.date.timeIntervalSinceReferenceDate * 3) + 1) / 2
                    SpectrumGradient(fractionLeft: wave * 0.12)
                }
            } else {
                Ticking(isActive: run.isLive) { now in
                    let left = run.fractionLeft(at: now)
                    GeometryReader { proxy in
                        SpectrumGradient(fractionLeft: left)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(.black.opacity(0.16)).frame(width: proxy.size.width * (1 - left))
                            }
                    }
                    .animation(.linear(duration: 0.5), value: left)
                }
                .saturation(run.isPaused ? 0.5 : 1)
            }
        }
        .accessibilityHidden(true)
    }
}
