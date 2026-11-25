import AppIntents
import SwiftUI
import TimingCore
import WidgetKit

struct TimersEntry: TimelineEntry {
    let date: Date
    let contents: TimerContents
    /// For the Lock Screen widget.
    var chosen: TimerEntity?
}

private enum Timers {
    static let sample = TimerContents(timers: [
        TimerDefinition(label: "Rice", seconds: 720), TimerDefinition(label: "Eggs", seconds: 390),
        TimerDefinition(label: "Pasta", seconds: 540), TimerDefinition(label: "Tea", seconds: 180),
    ])

    static func load(preview: Bool) -> TimerContents {
        preview ? sample : (try? TimerFile.shared?.load()) ?? TimerContents()
    }

    /// Now, and each moment a countdown ends.
    static func dates(_ contents: TimerContents, now: Date) -> [Date] {
        [now] + contents.runs.compactMap { if case .running(let end) = $0.phase, end > now { end } else { nil } }.sorted()
    }
}

struct TimersProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimersEntry { TimersEntry(date: .now, contents: Timers.sample) }
    func getSnapshot(in context: Context, completion: @escaping (TimersEntry) -> Void) {
        completion(TimersEntry(date: .now, contents: Timers.load(preview: context.isPreview)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimersEntry>) -> Void) {
        let contents = Timers.load(preview: false)
        // The app reloads this after every change.
        completion(Timeline(entries: Timers.dates(contents, now: .now).map { TimersEntry(date: $0, contents: contents) }, policy: .never))
    }
}

struct TimersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Timers", provider: TimersProvider()) { TimersWidgetView(entry: $0) }
            .configurationDisplayName("Timers")
            .description("Start your saved timers.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimersWidgetView: View {
    let entry: TimersEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let timers = Array(entry.contents.timers.prefix(family == .systemSmall ? 2 : 4))
        Group {
            if timers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Image("CatTimer").font(.title2).foregroundStyle(Color.accentFill).accessibilityHidden(true)
                    Spacer(minLength: 4)
                    Text("No timers yet").font(.headline)
                    Text("Tap to add one").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: family == .systemSmall ? 1 : 2)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(timers) { timer in
                        Button(intent: StartTimerIntent(timer: TimerEntity(timer))) { tile(timer) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }

    private func tile(_ timer: TimerDefinition) -> some View {
        let run = entry.contents.runs.first { $0.timer.id == timer.id }
        return VStack(alignment: .leading, spacing: 2) {
            Text(timer.displayLabel).font(.subheadline.weight(.semibold))
            RunTime(run: run, timer: timer, date: entry.date).font(.headline.monospacedDigit()).widgetAccentable()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(run == nil ? Color.primary : .white)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
            if run == nil { shape.fill(Color.primary.opacity(0.07)) } else { shape.fill(Color.accentFill) }
        }
    }
}

private struct RunTime: View {
    let run: TimerRun?
    let timer: TimerDefinition
    let date: Date

    var body: some View {
        switch run?.phase {
        case .running(let end)? where end > date: Text(timerInterval: date...end, countsDown: true)
        case .running?, .ringing?: Text("Time's up")
        case .paused?: Text("Paused")
        case nil: Text(DurationText.short(timer.seconds))
        }
    }
}

// MARK: One chosen timer

struct ChooseTimerIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Timer"
    @Parameter(title: "Timer") var timer: TimerEntity?
}

struct StartTimerProvider: AppIntentTimelineProvider {
    private func entry(_ configuration: ChooseTimerIntent, _ contents: TimerContents, _ date: Date) -> TimersEntry {
        // Read again, because the timer may have been renamed or deleted since it was chosen.
        let chosen = configuration.timer.flatMap { choice in contents.timers.first { $0.id == choice.id } }
        return TimersEntry(date: date, contents: contents, chosen: (chosen ?? (configuration.timer == nil ? contents.timers.first : nil)).map(TimerEntity.init))
    }
    func placeholder(in context: Context) -> TimersEntry { entry(ChooseTimerIntent(), Timers.sample, .now) }
    func snapshot(for configuration: ChooseTimerIntent, in context: Context) async -> TimersEntry {
        entry(configuration, Timers.load(preview: context.isPreview), .now)
    }
    func timeline(for configuration: ChooseTimerIntent, in context: Context) async -> Timeline<TimersEntry> {
        let contents = Timers.load(preview: false)
        return Timeline(entries: Timers.dates(contents, now: .now).map { entry(configuration, contents, $0) }, policy: .never)
    }
}

struct StartTimerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "StartTimer", intent: ChooseTimerIntent.self, provider: StartTimerProvider()) { entry in
            StartTimerView(entry: entry)
        }
        .configurationDisplayName("Start Timer")
        .description("Start one timer you choose.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct StartTimerView: View {
    let entry: TimersEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let chosen = entry.chosen, let timer = entry.contents.timers.first(where: { $0.id == chosen.id }) {
                let run = entry.contents.runs.first { $0.timer.id == timer.id }
                Button(intent: StartTimerIntent(timer: chosen)) {
                    if family == .accessoryCircular {
                        ZStack {
                            AccessoryWidgetBackground()
                            VStack(spacing: 0) {
                                Text(timer.displayLabel).font(.caption2)
                                RunTime(run: run, timer: timer, date: entry.date).font(.caption.weight(.semibold).monospacedDigit())
                                    .multilineTextAlignment(.center)
                            }
                            .padding(4)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            Label(timer.displayLabel, image: "CatTimer").font(.headline)
                            RunTime(run: run, timer: timer, date: entry.date).font(.title3.monospacedDigit()).widgetAccentable()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Label("No timer", image: "CatTimer").font(.caption)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .containerBackground(.clear, for: .widget)
    }
}

struct ChooseTimerControlIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Timer"
    @Parameter(title: "Timer") var timer: TimerEntity?
}

/// Starts the chosen timer from Control Center or the Lock Screen.
struct StartTimerControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: "StartTimerControl", intent: ChooseTimerControlIntent.self) { configuration in
            ControlWidgetButton(action: StartChosenTimerIntent(timer: configuration.timer)) {
                Label(configuration.timer?.label ?? "Choose a timer", image: "CatTimer")
            }
        }
        .displayName("Start Timer")
        .description("Starts a timer you choose.")
        .promptsForUserConfiguration()
    }
}
