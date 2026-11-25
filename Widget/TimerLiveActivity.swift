import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import TimingCore
import WidgetKit

@main
struct TimingWidgets: WidgetBundle {
    var body: some Widget {
        TimersWidget()
        StartTimerWidget()
        StartTimerControl()
        TimerLiveActivity()
    }
}

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<RingMetadata>.self) { context in
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Text([context.attributes.metadata?.icon, context.attributes.metadata?.label ?? "Timer"].compactMap(\.self).joined(separator: " ")).font(.headline).lineLimit(1)
                    Spacer()
                    Remaining(state: context.state).font(.title.weight(.semibold))
                    if let snapshot = context.attributes.metadata?.snapshot {
                        Buttons(snapshot: snapshot, isPaused: context.state.mode.isPaused)
                    }
                }
                Progress(state: context.state)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(LinearGradient(
                colors: [Color(white: 0.05), Color(red: 0.10, green: 0.06, blue: 0.20), Color(red: 0.20, green: 0.10, blue: 0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        } dynamicIsland: { context in
            // iOS chooses which timer's activity fills the island, so each one shows the timer closest to ringing.
            let shown = IslandTimer(context: context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(shown.icon) \(shown.label)").font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) { shown.remaining.font(.title2.weight(.semibold)) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        shown.progress
                        if let snapshot = shown.snapshot { Buttons(snapshot: snapshot, isPaused: shown.isPaused) }
                    }
                }
            } compactLeading: {
                Text(shown.icon).accessibilityLabel(shown.label)
            } compactTrailing: {
                shown.remaining.frame(maxWidth: 56).foregroundStyle(Color.accentBright)
            } minimal: {
                Text(context.attributes.metadata?.icon ?? TimerIcon.fallback)
                    .accessibilityLabel(context.attributes.metadata?.label ?? "Timer")
            }
            .keylineTint(.accentBright)
        }
    }
}

private struct Remaining: View {
    let state: AlarmPresentationState

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                Text(timerInterval: countdown.startDate...max(countdown.startDate, countdown.fireDate), countsDown: true)
            case .paused(let paused):
                Text(DurationText.countdown(paused.totalCountdownDuration - paused.previouslyElapsedDuration)).opacity(0.7)
            default: EmptyView()
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct Progress: View {
    let state: AlarmPresentationState

    var body: some View {
        Group {
            switch state.mode {
            case .countdown(let countdown):
                // From where the whole countdown would have begun, so a pause does not reset it.
                let start = countdown.startDate.addingTimeInterval(-countdown.previouslyElapsedDuration)
                ProgressView(timerInterval: start...max(start, countdown.fireDate), countsDown: false) {
                    EmptyView()
                } currentValueLabel: { EmptyView() }
            case .paused(let paused):
                ProgressView(value: min(1, paused.previouslyElapsedDuration / max(1, paused.totalCountdownDuration)))
            default: EmptyView()
            }
        }
        .tint(LinearGradient(colors: [.accentFill, .accentBright], startPoint: .leading, endPoint: .trailing))
    }
}

private struct Buttons: View {
    let snapshot: String
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isPaused {
                button("play.fill", "Resume", ResumeTimerIntent(snapshot: snapshot))
            } else {
                button("pause.fill", "Pause", PauseTimerIntent(snapshot: snapshot))
            }
            button("xmark", "Stop", StopTimerIntent(snapshot: snapshot))
        }
    }

    private func button(_ symbol: String, _ name: String, _ intent: some LiveActivityIntent) -> some View {
        Button(intent: intent) {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
                .background(.white.opacity(0.16), in: .circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(name)
    }
}

extension AlarmPresentationState.Mode {
    var isPaused: Bool { if case .paused = self { true } else { false } }
}

/// The running timer closest to ringing, from the copy the app shares with its widgets.
/// Falls back to the activity's own timer when there is none, or when this one is ringing.
private struct IslandTimer {
    let label: String
    let icon: String
    let snapshot: String?
    let isPaused: Bool
    private let end: Date?
    private let total: TimeInterval?
    private let state: AlarmPresentationState

    init(context: ActivityViewContext<AlarmAttributes<RingMetadata>>) {
        state = context.state
        let isRinging = if case .alert = context.state.mode { true } else { false }
        let soonest = isRinging ? nil : (try? TimerFile.shared?.load())?.soonest(after: .now)
        if let soonest, case .running(let endsAt) = soonest.phase {
            label = soonest.timer.displayLabel
            icon = soonest.timer.displayIcon
            snapshot = try? RunSnapshot.encode(soonest)
            isPaused = false
            end = endsAt
            total = soonest.total
        } else {
            label = context.attributes.metadata?.label ?? "Timer"
            icon = context.attributes.metadata?.icon ?? TimerIcon.fallback
            snapshot = context.attributes.metadata?.snapshot
            isPaused = context.state.mode.isPaused
            end = nil
            total = nil
        }
    }

    @ViewBuilder var remaining: some View {
        if let end {
            Text(timerInterval: Date.now...max(.now, end), countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Remaining(state: state)
        }
    }

    @ViewBuilder var progress: some View {
        if let end, let total {
            let start = end.addingTimeInterval(-total)
            ProgressView(timerInterval: start...max(start, end), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(LinearGradient(colors: [.accentFill, .accentBright], startPoint: .leading, endPoint: .trailing))
        } else {
            Progress(state: state)
        }
    }
}
