import AlarmKit
import SwiftUI
import TimingCore

struct TimersView: View {
    let model: TimerModel
    @State private var editing: TimerDefinition?
    @State private var reorders = false
    @State private var errorMessage: String?
    @State private var startCount = 0
    @State private var scrollTarget: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var zoom
    private static let addSource = "add"

    private var isEmpty: Bool {
        model.timers.isEmpty && model.runs.isEmpty && !model.permissionDenied && !model.storageFailed
    }

    var body: some View {
        Group {
            if isEmpty { EmptyTimers() } else { content }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.canvas.ignoresSafeArea())
        .safeAreaBar(edge: .bottom) {
            QuickEntryBar(saved: model.timers, addSource: Self.addSource, zoom: zoom, start: start) { editing = Services.newTimers.blank() }
        }
        .animation(.smooth(duration: 0.35), value: model.timers)
        .animation(.smooth(duration: 0.35), value: model.runs)
        .sheet(item: $editing) { timer in
            let isNew = !model.isSaved(timer)
            TimerEditorView(model: model, timer: timer, isNew: isNew) { errorMessage = $0 }
                .navigationTransition(.zoom(sourceID: isNew ? AnyHashable(Self.addSource) : AnyHashable(timer.id), in: zoom))
        }
        .sheet(isPresented: $reorders) { ReorderView(model: model) { errorMessage = $0 } }
        .alert("Timer not changed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
        .sensoryFeedback(.success, trigger: startCount)
        .onChange(of: scenePhase == .active && model.runs.contains(where: \.isLive), initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
    }

    private var content: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.permissionDenied { permissionBanner }
                    if model.storageFailed {
                        Label("Your timers could not be read. Timers already running will still ring.", systemImage: "exclamationmark.triangle.fill")
                            .padding(20)
                    }
                    if !model.timers.isEmpty || !model.runs.isEmpty { Header(runs: model.runs) }
                    ForEach(model.runs) { run in
                        RunRow(run: run, model: model, perform: attempt)
                            .contextMenu { runMenu(run) }
                            .id(run.id)
                            .transition(.opacity)
                    }
                    if !model.timers.isEmpty { grid }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.smooth) { scroll.scrollTo(target, anchor: .center) }
                scrollTarget = nil
            }
        }
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(model.timers) { timer in
                let run = model.runs.first { $0.timer.id == timer.id }
                Button { tap(timer, run) } label: { TimerTile(timer: timer, run: run) }
                    .buttonStyle(SpringyButtonStyle(scale: 0.95))
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(run == nil ? "Starts this timer" : "Shows this timer")
                    .accessibilityIdentifier("tile-\(timer.label)")
                    .matchedTransitionSource(id: timer.id, in: zoom)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: 20, style: .continuous))
                    .contextMenu { tileMenu(timer, isRunning: run != nil) }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    @ViewBuilder private func tileMenu(_ timer: TimerDefinition, isRunning: Bool) -> some View {
        if isRunning { Button("Start another", systemImage: "plus") { startNow(timer) } }
        Button("Edit", systemImage: "pencil") { editing = timer }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            attempt {
                try await model.save(TimerDefinition(label: timer.label, seconds: timer.seconds, tone: timer.tone,
                                                     ringButton: timer.ringButton, addMinutes: timer.addMinutes))
            }
        }
        if model.timers.count > 1 { Button("Reorder", systemImage: "arrow.up.arrow.down") { reorders = true } }
        Button("Delete", systemImage: "trash", role: .destructive) { attempt { try await model.delete(timer.id) } }
    }

    @ViewBuilder private func runMenu(_ run: TimerRun) -> some View {
        Button("Add \(run.timer.addMinutes)m", systemImage: "plus") { attempt { try await model.addTime(run) } }
        Button("Start again", systemImage: "arrow.counterclockwise") { attempt { try await model.repeat(run) } }
        if !model.isSaved(run.timer) {
            Button("Save timer", systemImage: "square.and.arrow.down") { attempt { try await model.save(run.timer) } }
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Alarms are turned off", systemImage: "bell.slash.fill").font(.headline)
            Text("Allow Timing to set alarms in Settings, or nothing will ring.").foregroundStyle(Color.quiet)
            Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
                .buttonStyle(.plain)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentText)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private func tap(_ timer: TimerDefinition, _ run: TimerRun?) {
        if let run { scrollTarget = run.id } else {
            attempt {
                // Through the same path as widgets, which never makes a duplicate.
                try await model.startSaved(timer.id)
                startCount += 1
            }
        }
    }

    private func startNow(_ timer: TimerDefinition) {
        attempt {
            try await model.start(timer)
            startCount += 1
        }
    }

    private func start(_ action: DurationEntry.Action) async -> Bool {
        do {
            if case .startAndSave(let timer) = action { try await model.start(timer, saving: true) } else { try await model.start(action.timer) }
            startCount += 1
            return true
        } catch {
            errorMessage = ErrorText.message(for: error)
            return false
        }
    }

    private func attempt(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work() } catch { errorMessage = ErrorText.message(for: error) }
        }
    }
}

extension TimerRun {
    var isLive: Bool { if case .paused = phase { false } else { true } }
    var isRinging: Bool { phase == .ringing }
    var isPaused: Bool { !isLive }
}

/// Redraws twice a second only while a timer is counting.
struct Ticking<Content: View>: View {
    let isActive: Bool
    @ViewBuilder let content: (Date) -> Content

    var body: some View {
        if isActive {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in content(max(context.date, .now)) }
        } else {
            content(.now)
        }
    }
}

private struct Header: View {
    let runs: [TimerRun]

    var body: some View {
        Ticking(isActive: runs.first?.isLive == true) { now in
            let text = text(now)
            Text(text)
                .font(.title2.weight(.semibold))
                .tracking(-0.4)
                .contentTransition(.numericText())
                .animation(.snappy, value: text)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("header")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func text(_ now: Date) -> String {
        let ringing = runs.filter(\.isRinging)
        if ringing.count > 1 { return "\(ringing.count) timers are ringing" }
        guard let first = runs.first else { return "No timers running" }
        let label = first.timer.displayLabel
        if first.isRinging { return "\(label) is ringing" }
        return first.isPaused ? "\(label) is paused" : "\(label) in \(DurationText.rough(first.remaining(at: now)))"
    }
}

private struct TimerTile: View {
    let timer: TimerDefinition
    let run: TimerRun?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(timer.displayLabel).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if let run {
                    Image(systemName: run.isRinging ? "bell.fill" : run.isPaused ? "pause.fill" : "timer")
                        .foregroundStyle(Color.accentText)
                        .accessibilityLabel(run.isRinging ? "Ringing" : run.isPaused ? "Paused" : "Running")
                }
            }
            Spacer(minLength: 0)
            Text(DurationText.short(timer.seconds))
                .font(.title2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(run == nil ? Color.primary : Color.accentText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(run == nil ? Color.chip : Color.accentFill.opacity(0.14), in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(run == nil ? Color.hairline : Color.accentFill.opacity(0.5), lineWidth: 1)
        }
        .contentShape(.rect)
    }
}

private struct EmptyTimers: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.accentFill.opacity(0.24), .orange.opacity(0.16), .yellow.opacity(0.10)],
                           startPoint: .leading, endPoint: .trailing)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center))
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 8) {
                    TimerMark()
                    Text("No timers yet").font(.title2.weight(.semibold)).tracking(-0.4)
                    Text("Type 9m pasta below, or tap + for the wheel.").foregroundStyle(Color.quiet)
                }
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.center, for: .alignment)
        }
    }
}

enum ErrorText {
    static func message(for error: any Error) -> String {
        switch error {
        case TimerModelError.permissionDenied: "Allow Timing to set alarms in Settings, then try again."
        case TimerModelError.storageUnavailable: "Your saved timers could not be read. Unlock your iPhone and try again."
        case AlarmManager.AlarmError.maximumLimitReached: "iOS has reached its limit for timers. Stop one and try again."
        default: "iOS could not change this timer. Please try again."
        }
    }
}
