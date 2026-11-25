#if DEBUG
import SwiftUI
import TimingCore

/// The Home Screen widget at an iPhone 18 Pro's widget sizes, for screenshots. Run with -widgets.
struct WidgetGallery: View {
    private let now = Date.now

    private var timers: [TimerDefinition] {
        [("Eggs", 390), ("Rice", 720), ("Sourdough", 2700), ("Pancakes", 90), ("Tea", 180), ("Pasta", 540)]
            .map { TimerDefinition(label: $0, seconds: $1) }
    }

    private func contents(_ count: Int) -> TimerContents {
        let phases: [TimerRun.Phase] = [.ringing, .running(endsAt: now + 78), .running(endsAt: now + 498),
                                        .paused(remaining: 2520), .running(endsAt: now + 150), .running(endsAt: now + 300)]
        return TimerContents(timers: timers, runs: (0..<count).map {
            TimerRun(timer: timers[$0], total: TimeInterval(timers[$0].seconds), phase: phases[$0])
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    widget(contents(0), .small)
                    widget(contents(2), .small)
                }
                widget(contents(1), .medium)
                widget(contents(3), .medium)
                HStack(spacing: 16) {
                    widget(contents(5), .small)
                    widget(contents(1), .small)
                }
                widget(contents(6), .medium)
            }
            .padding(16)
        }
        .background(Color(red: 0.25, green: 0.27, blue: 0.45).ignoresSafeArea())
    }

    /// 170 and 364 by 170 points, with the 16 point margin iOS gives widget content.
    private func widget(_ contents: TimerContents, _ size: ActiveTimersView.Size) -> some View {
        ActiveTimersView(contents: contents, date: now, size: size)
            .padding(16)
            .frame(width: size == .small ? 170 : 364, height: 170)
            .background(.background, in: .rect(cornerRadius: 24, style: .continuous))
    }
}
#endif
