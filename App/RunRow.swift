import SwiftUI
import TimingCore

/// A countdown readable from across the kitchen. It grows its buttons when it rings.
struct RunRow: View {
    let run: TimerRun
    let model: TimerModel
    let perform: (@escaping () async throws -> Void) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 10))
            layout {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.timer.displayLabel).font(.headline).lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    Ticking(isActive: run.isLive && !run.isRinging) { now in
                        let text = DurationText.countdown(run.remaining(at: now))
                        Text(text)
                            .font(.system(size: min(timeSize, 84), weight: .medium).monospacedDigit())
                            .tracking(-1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.snappy, value: text)
                            .opacity(run.isPaused ? 0.7 : 1)
                            .accessibilityIdentifier("countdown-\(run.timer.displayLabel)")
                    }
                    Text(status).font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !run.isRinging {
                    HStack(spacing: 10) {
                        circle(run.isPaused ? "play.fill" : "pause.fill", run.isPaused ? "Resume" : "Pause") {
                            if run.isPaused { try await model.resume(run.id) } else { try await model.pause(run.id) }
                        }
                        circle("xmark", "Stop") { try await model.stop(run) }
                    }
                }
            }
            if run.isRinging { ringButtons }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background { RunGlow(run: run) }
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.18)).frame(height: 1) }
        .contentShape(.rect)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: run.isPaused)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("run-\(run.timer.displayLabel)")
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

    private func circle(_ symbol: String, _ name: String, _ work: @escaping () async throws -> Void) -> some View {
        Button { perform(work) } label: {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.22), in: .circle)
                .contentShape(.circle)
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

/// Heat filling the row. It drains as time passes and glows slowly while ringing.
private struct RunGlow: View {
    let run: TimerRun
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if run.isRinging {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { context in
                    let wave = reduceMotion ? 0 : (sin(context.date.timeIntervalSinceReferenceDate * 3) + 1) / 2
                    HeatGradient(fractionLeft: wave * 0.12)
                }
            } else {
                Ticking(isActive: run.isLive) { now in
                    let left = run.fractionLeft(at: now)
                    GeometryReader { proxy in
                        HeatGradient(fractionLeft: left)
                            .overlay(alignment: .trailing) {
                                Rectangle().fill(.black.opacity(0.16)).frame(width: proxy.size.width * (1 - left))
                            }
                    }
                    .animation(.linear(duration: 0.5), value: left)
                }
                .saturation(run.isPaused ? 0.35 : 1)
            }
        }
        .accessibilityHidden(true)
    }
}
