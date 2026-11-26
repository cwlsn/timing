import AlarmKit
import SwiftUI
import TimingCore

struct TimersView: View {
    let model: TimerModel
    @State private var editing: TimerDefinition?
    @State private var editSource: AnyHashable = TimersView.addSource
    @State private var path: [TimerCategory] = []
    /// Order is taken when the app opens, so a tile never moves under a finger.
    @State private var order: [UUID] = []
    @State private var categoryOrder: [TimerCategory] = []
    @State private var errorMessage: String?
    @State private var startCount = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var zoom
    private static let addSource = "add"

    private var isEmpty: Bool {
        model.timers.isEmpty && model.runs.isEmpty && !model.permissionDenied && !model.storageFailed
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isEmpty { EmptyTimers() } else { content }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvas.ignoresSafeArea())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .safeAreaBar(edge: .bottom) {
                QuickEntryBar(saved: model.timers, addSource: Self.addSource, zoom: zoom, start: start) { add(Services.newTimers.blank()) }
            }
            .navigationDestination(for: TimerCategory.self) { categoryScreen($0) }
        }
        .animation(.smooth(duration: 0.35), value: model.timers)
        .animation(.smooth(duration: 0.35), value: model.runs)
        .sheet(item: $editing) { timer in
            TimerEditorView(model: model, timer: timer, isNew: !model.isSaved(timer)) { started() } onError: { errorMessage = $0 }
                .navigationTransition(.zoom(sourceID: editSource, in: zoom))
        }
        .alert("Timer not changed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
        .sensoryFeedback(.success, trigger: startCount)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            order = model.timersByUse.map(\.id)
            categoryOrder = TimerContents(timers: model.timers).categoriesByUse
        }
        .onChange(of: scenePhase == .active && model.runs.contains(where: \.isLive), initial: true) { _, awake in
            UIApplication.shared.isIdleTimerDisabled = awake
        }
        .onChange(of: model.timers) {
            // A category emptied by deleting its last timer has nothing left to show.
            if let shown = path.last, tiles(in: shown).isEmpty { path.removeAll() }
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
                    if !model.runs.isEmpty { cards }
                    if !model.timers.isEmpty { categoryGrid }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
    }

    private var cards: some View {
        let isWide = model.runs.map { $0.isRinging || typeSize.isAccessibilitySize }
        let full = CardRows.full(isWide)
        return CardLayout {
            ForEach(Array(model.runs.enumerated()), id: \.element.id) { index, run in
                RunCard(run: run, isFull: full.contains(index), model: model, perform: attempt)
                    .contentShape(.contextMenuPreview, .rect(cornerRadius: 20, style: .continuous))
                    .contextMenu { runMenu(run) }
                    .wideCard(isWide[index])
                    .id(run.id)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
    }

    /// Categories and timers added since the app opened go last.
    private var categories: [TimerCategory] {
        let shown = TimerContents(timers: model.timers).categoriesByUse
        return categoryOrder.filter(shown.contains) + shown.filter { !categoryOrder.contains($0) }
    }

    private func tiles(in category: TimerCategory) -> [TimerDefinition] {
        let byUse = model.timersByUse.filter { $0.displayCategory == category }
        return order.compactMap { id in byUse.first { $0.id == id } } + byUse.filter { !order.contains($0.id) }
    }

    private var categoryGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(categories) { category in
                let timers = tiles(in: category)
                let runs = model.runs.filter { $0.timer.displayCategory == category }
                let status = CategoryTile.status(timers: timers.count, runs: runs)
                NavigationLink(value: category) { CategoryTile(category: category, status: status, isActive: !runs.isEmpty) }
                    .buttonStyle(SpringyButtonStyle(scale: 0.95))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(category.name), \(timers.count) \(timers.count == 1 ? "timer" : "timers")")
                    .accessibilityValue(runs.isEmpty ? "" : status)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("category-\(category.name)")
                    .matchedTransitionSource(id: category, in: zoom)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func categoryScreen(_ category: TimerCategory) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize ? 1 : 3)
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(tiles(in: category)) { timer in
                    let run = model.runs.first { $0.timer.id == timer.id }
                    Button { tap(timer) } label: { TimerTile(timer: timer, run: run) }
                        .buttonStyle(SpringyButtonStyle(scale: 0.95))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(timer.isNamedForLength ? timer.label : "\(timer.displayLabel), \(DurationText.short(timer.seconds))")
                        .accessibilityValue(run.map { $0.isRinging ? "Ringing" : $0.isPaused ? "Paused" : "Running" } ?? "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Starts this timer")
                        .accessibilityIdentifier("tile-\(timer.label)")
                        .matchedTransitionSource(id: timer.id, in: zoom)
                        .contentShape(.contextMenuPreview, .rect(cornerRadius: 20, style: .continuous))
                        .contextMenu { tileMenu(timer) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(category.name)
        .navigationTransition(.zoom(sourceID: category, in: zoom))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New timer", systemImage: "plus") {
                    var timer = Services.newTimers.blank()
                    timer.category = category
                    add(timer, from: category)
                }
                .accessibilityIdentifier("add-\(category.name)")
            }
            .matchedTransitionSource(id: "add-\(category.rawValue)", in: zoom)
        }
    }

    @ViewBuilder private func tileMenu(_ timer: TimerDefinition) -> some View {
        Button("Edit", systemImage: "pencil") {
            editSource = timer.id
            editing = timer
        }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            attempt {
                try await model.save(TimerDefinition(label: timer.label, seconds: timer.seconds, tone: timer.tone,
                                                     ringButton: timer.ringButton, addMinutes: timer.addMinutes, icon: timer.icon,
                                                     category: timer.category))
            }
        }
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

    /// Always a new run, even beside one of the same timer.
    private func tap(_ timer: TimerDefinition) {
        attempt {
            try await model.startSaved(timer.id)
            started()
        }
    }

    /// Back to the main screen, where the new countdown is.
    private func started() {
        startCount += 1
        path.removeAll()
    }

    private func add(_ timer: TimerDefinition, from category: TimerCategory? = nil) {
        editSource = category.map { AnyHashable("add-\($0.rawValue)") } ?? AnyHashable(Self.addSource)
        editing = timer
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
        // A name that is only a length reads badly beside another length.
        let label = first.timer.isNamedForLength ? nil : first.timer.displayLabel
        if first.isRinging { return label.map { "\($0) is ringing" } ?? "Time's up" }
        if first.isPaused { return label.map { "\($0) is paused" } ?? "Paused" }
        return "\(label ?? "Rings") in \(DurationText.rough(first.remaining(at: now)))"
    }
}

private struct CategoryTile: View {
    let category: TimerCategory
    let status: String
    let isActive: Bool

    /// Running wins over paused, since it is what needs watching.
    static func status(timers: Int, runs: [TimerRun]) -> String {
        let paused = runs.filter(\.isPaused).count
        if runs.count > paused { return "\(runs.count - paused) running" }
        if paused > 0 { return "\(paused) paused" }
        return "\(timers) \(timers == 1 ? "timer" : "timers")"
    }
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 34

    var body: some View {
        HStack(spacing: 12) {
            Text(category.icon)
                .font(.system(size: min(iconSize, 56)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(status)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(isActive ? Color.accentText : Color.quiet)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(!isActive ? Color.chip : Color.accentFill.opacity(0.14), in: .rect(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(!isActive ? Color.hairline : Color.accentFill.opacity(0.5), lineWidth: 1)
        }
        .contentShape(.rect)
    }
}

private struct TimerTile: View {
    let timer: TimerDefinition
    let run: TimerRun?
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 46

    var body: some View {
        VStack(spacing: 4) {
            Text(timer.displayIcon)
                .font(.system(size: min(iconSize, 72)))
                .accessibilityHidden(true)
            Text(DurationText.short(timer.seconds))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(run == nil ? Color.primary : Color.accentText)
            if !timer.isNamedForLength {
                Text(timer.displayLabel).font(.footnote).foregroundStyle(Color.quiet)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 124)
        .overlay(alignment: .topTrailing) {
            if let run {
                Image(systemName: run.isRinging ? "bell.fill" : run.isPaused ? "pause.fill" : "timer")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentText)
                    .padding(10)
            }
        }
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
            LinearGradient(colors: [.blue.opacity(0.18), .accentFill.opacity(0.22), .magenta.opacity(0.16)],
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
