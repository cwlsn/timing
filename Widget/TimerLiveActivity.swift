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
                    Text(context.attributes.metadata?.label ?? "Timer").font(.headline).lineLimit(1)
                    Spacer()
                    Remaining(state: context.state).font(.title.weight(.semibold))
                    Buttons(context: context)
                }
                Progress(state: context.state)
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(LinearGradient(
                colors: [Color(white: 0.05), Color(red: 0.16, green: 0.07, blue: 0.04), Color(red: 0.36, green: 0.13, blue: 0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.label ?? "Timer").font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) { Remaining(state: context.state).font(.title2.weight(.semibold)) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        Progress(state: context.state)
                        Buttons(context: context)
                    }
                }
            } compactLeading: {
                Image("CatTimer").foregroundStyle(Color.accentBright)
            } compactTrailing: {
                Remaining(state: context.state).frame(maxWidth: 52).foregroundStyle(Color.accentBright)
            } minimal: {
                Image("CatTimer").foregroundStyle(Color.accentBright)
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
    let context: ActivityViewContext<AlarmAttributes<RingMetadata>>

    var body: some View {
        if let snapshot = context.attributes.metadata?.snapshot {
            HStack(spacing: 8) {
                if case .paused = context.state.mode {
                    button("play.fill", "Resume", ResumeTimerIntent(snapshot: snapshot))
                } else {
                    button("pause.fill", "Pause", PauseTimerIntent(snapshot: snapshot))
                }
                button("xmark", "Stop", StopTimerIntent(snapshot: snapshot))
            }
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
