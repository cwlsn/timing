import SwiftUI
import TimingCore

/// Every property on one screen. Closing an existing timer saves it, so there is no Save button to find.
struct TimerEditorView: View {
    let model: TimerModel
    let isNew: Bool
    let onError: (String) -> Void
    @State private var draft: TimerDefinition
    @State private var original: TimerDefinition
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isDeleted = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(model: TimerModel, timer: TimerDefinition, isNew: Bool, onError: @escaping (String) -> Void) {
        self.model = model
        self.isNew = isNew
        self.onError = onError
        var draft = timer
        // Shown as a placeholder so there is nothing to clear before typing.
        if draft.label == TimerDefinition.defaultLabel { draft.label = "" }
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    wheels
                    VStack(spacing: 26) {
                        TonePicker(tone: $draft.tone)
                        Divider()
                        ringButton
                        if !isNew {
                            Divider()
                            Button("Delete timer", role: .destructive, action: delete)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .background(Color.canvas.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .disabled(isSaving)
            .alert("Timer not saved", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") {}
            } message: { Text(errorMessage ?? "") }
        }
        .onDisappear { saveChanges() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { saveChanges() }
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isNew {
                Button("Cancel") { dismiss() }
            } else if draft != original {
                Button("Revert", systemImage: "arrow.uturn.backward") { withAnimation(.smooth) { draft = original } }
            }
        }
        ToolbarItem(placement: .principal) {
            TextField(TimerDefinition.defaultLabel, text: $draft.label)
                .font(.headline)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .frame(minWidth: 120, minHeight: 44)
                .accessibilityLabel("Label")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(isNew ? "Add" : "Done") { isNew ? add() : dismiss() }
                .buttonStyle(.glassProminent)
                .tint(.accentFill)
                .disabled(draft.seconds < 1)
        }
    }

    private var wheels: some View {
        HStack(spacing: 0) {
            wheel("hr", unit: 3600, count: 24)
            wheel("min", unit: 60, count: 60)
            wheel("sec", unit: 1, count: 60)
        }
        .frame(height: 190)
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background {
            // Longer timers are cooler.
            HeatGradient(fractionLeft: min(1, Double(draft.seconds) / 3600))
                .opacity(0.30)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .padding(.top, -160)
                .animation(.smooth, value: draft.seconds)
        }
    }

    private func wheel(_ name: String, unit: Int, count: Int) -> some View {
        let value = Binding(
            get: { draft.seconds / unit % count },
            set: { draft.seconds += ($0 - draft.seconds / unit % count) * unit })
        return Picker(name, selection: value) {
            ForEach(0..<count, id: \.self) { Text("\($0) \(name)").monospacedDigit().tag($0) }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .accessibilityLabel(name)
    }

    private var ringButton: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Beside Stop when it rings").font(.subheadline)
            Picker("Beside Stop when it rings", selection: $draft.ringButton) {
                Text("Add time").tag(RingButton.addTime)
                Text("Repeat").tag(RingButton.repeat)
            }
            .pickerStyle(.segmented)
            Stepper(value: $draft.addMinutes, in: TimerDefinition.addMinutesRange) {
                Text("Add \(draft.addMinutes) min").font(.subheadline).monospacedDigit()
            }
            .frame(minHeight: 44)
            Text("The app always offers both.").font(.footnote).foregroundStyle(Color.quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        isSaving = true
        Task {
            do {
                try await model.save(draft)
                Services.newTimers.remember(draft)
                dismiss()
            } catch {
                errorMessage = ErrorText.message(for: error)
                isSaving = false
            }
        }
    }

    private func delete() {
        isSaving = true
        Task {
            do {
                try await model.delete(draft.id)
                isDeleted = true
                dismiss()
            } catch {
                errorMessage = ErrorText.message(for: error)
                isSaving = false
            }
        }
    }

    private func saveChanges() {
        guard !isNew, !isDeleted, draft != original, model.isSaved(draft) else { return }
        var changed = draft
        // No length cannot be a timer, so the old one stays.
        if changed.seconds < 1 { changed.seconds = original.seconds }
        let before = original
        original = draft
        Task {
            do {
                try await model.save(changed)
                Services.newTimers.remember(changed)
            } catch {
                original = before
                onError(ErrorText.message(for: error))
            }
        }
    }
}

struct ReorderView: View {
    let model: TimerModel
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.timers) { timer in
                    HStack {
                        Text(timer.displayLabel)
                        Spacer()
                        Text(DurationText.short(timer.seconds)).foregroundStyle(Color.quiet).monospacedDigit()
                    }
                }
                .onMove { source, target in
                    var ids = model.timers.map(\.id)
                    ids.move(fromOffsets: source, toOffset: target)
                    Task {
                        do { try await model.reorder(ids) } catch { onError(ErrorText.message(for: error)) }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.buttonStyle(.glassProminent).tint(.accentFill)
                }
            }
        }
    }
}
