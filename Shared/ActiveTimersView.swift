import AppIntents
import SwiftUI
import TimingCore

/// The Home Screen widget: running timers, and a way into the app to start another.
/// In Shared so a test screen in the app can show it at widget sizes.
struct ActiveTimersView: View {
    enum Size { case small, medium }

    let contents: TimerContents
    let date: Date
    let size: Size

    private var capacity: Int { size == .small ? 2 : 4 }

    var body: some View {
        let runs = contents.runs
        Group {
            if runs.isEmpty {
                empty
            } else if size == .small {
                VStack(spacing: 6) {
                    if runs.count == 1 { card(runs[0], isAlone: true) } else { ForEach(runs.prefix(capacity)) { card($0) } }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        newButton
                        more(runs.count)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    mediumCards(runs).frame(maxHeight: .infinity, alignment: .top)
                    VStack(spacing: 6) {
                        newButton.frame(maxHeight: .infinity)
                        more(runs.count)
                    }
                    .frame(width: 64)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One fills the space, two are rows, and more share a grid.
    @ViewBuilder private func mediumCards(_ runs: [TimerRun]) -> some View {
        switch runs.count {
        case 1: card(runs[0], isAlone: true)
        case 2: VStack(spacing: 8) { ForEach(runs) { card($0) } }
        default:
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: min(runs.count, capacity), by: 2)), id: \.self) { start in
                    GridRow {
                        card(runs[start])
                        if start + 1 < runs.count { card(runs[start + 1]) } else { Color.clear }
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image("CatTimer").font(.title2).foregroundStyle(Color.accentFill).accessibilityHidden(true)
            Spacer(minLength: 4)
            Text("No timers running").font(.headline)
            Spacer(minLength: 8)
            newButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// Opens the app. Tapping anywhere else opens it too, but never starts a timer.
    private var newButton: some View {
        Button(intent: OpenTimingIntent()) {
            Label("New", systemImage: "plus")
                .labelStyle(NewLabelStyle(isTall: size == .medium && !contents.runs.isEmpty))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .frame(maxHeight: .infinity)
                .background(Color.accentFill, in: .rect(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: size == .small || contents.runs.isEmpty)
        .accessibilityLabel("New timer")
    }

    @ViewBuilder private func more(_ count: Int) -> some View {
        if count > capacity {
            Text("+\(count - capacity)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(count - capacity) more")
        }
    }

    private func card(_ run: TimerRun, isAlone: Bool = false) -> some View {
        Group {
            if isAlone {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(run.timer.displayIcon) \(run.timer.displayLabel)").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    time(run).font(.system(size: 34, weight: .medium).monospacedDigit())
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 6) {
                    Text(run.timer.displayIcon).font(.title3).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        time(run).font(.headline.monospacedDigit())
                        Text(run.timer.displayLabel).font(.caption2.weight(.medium)).opacity(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46)
                .frame(maxHeight: size == .medium ? .infinity : 46)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .foregroundStyle(.white)
        .background {
            SpectrumGradient(fractionLeft: run.isRinging ? 0 : run.fractionLeft(at: date))
                .saturation(run.isPaused ? 0.5 : 1)
                .clipShape(.rect(cornerRadius: 14, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func time(_ run: TimerRun) -> some View {
        switch run.phase {
        case .running(let end) where end > date: Text(timerInterval: date...end, countsDown: true)
        case .running, .ringing: Text("Time's up")
        case .paused(let left): Text("\(Image(systemName: "pause.fill")) \(DurationText.countdown(left))")
        }
    }
}

/// The symbol above the word in a tall button, beside it otherwise.
private struct NewLabelStyle: LabelStyle {
    let isTall: Bool

    func makeBody(configuration: Configuration) -> some View {
        if isTall {
            VStack(spacing: 4) { configuration.icon.font(.title2.weight(.semibold)); configuration.title }
        } else {
            HStack(spacing: 6) { configuration.icon; configuration.title }
        }
    }
}
