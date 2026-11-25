import SwiftUI
import TimingCore

/// Type a whole timer in one line, or open the wheel.
struct QuickEntryBar: View {
    let saved: [TimerDefinition]
    let addSource: String
    let zoom: Namespace.ID
    let start: (DurationEntry.Action) async -> Bool
    let openWheel: () -> Void
    @State private var text = ""
    @State private var isStarting = false
    @FocusState private var focused: Bool

    private var action: DurationEntry.Action? {
        DurationEntry.action(for: text, saved: saved, template: Services.newTimers.blank())
    }

    var body: some View {
        // Each reading makes a new identity, so animate on whether there is one.
        let action = action
        VStack(spacing: 8) {
            if !text.isEmpty {
                preview(action)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(spacing: 10) {
                TextField("9m pasta", text: $text)
                    .focused($focused)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .onSubmit(submit)
                    .accessibilityLabel("Quick start")
                    .padding(.horizontal, 18)
                    .frame(minHeight: 50)
                    .glassEffect(.regular.interactive(), in: .capsule)
                Button {
                    if action == nil { openWheel() } else { submit() }
                } label: {
                    Image(systemName: action == nil ? "plus" : "arrow.up")
                        .font(.system(size: 19, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(SpringyButtonStyle())
                .glassEffect(.regular.tint(.accentFill).interactive(), in: .circle)
                .matchedTransitionSource(id: addSource, in: zoom)
                .accessibilityLabel(action == nil ? "Add timer" : "Start timer")
                .disabled(isStarting)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: action == nil)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: text.isEmpty)
    }

    @ViewBuilder private func preview(_ action: DurationEntry.Action?) -> some View {
        if let action {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(DurationText.short(action.timer.seconds)) · \(action.timer.displayLabel)").font(.subheadline.weight(.semibold))
                Text(outcome(action)).font(.footnote).foregroundStyle(Color.quiet)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("quick-preview")
        } else {
            Text("Add a length, like 9m or 1h30").font(.subheadline).foregroundStyle(Color.quiet)
        }
    }

    private func outcome(_ action: DurationEntry.Action) -> String {
        switch action {
        case .startAndSave: "Starts and saves"
        case .startOnce: "Starts once"
        case .startSaved(let timer):
            saved.first { $0.id == timer.id }?.seconds == timer.seconds ? "Starts your saved timer" : "Starts with this length, once"
        }
    }

    private func submit() {
        guard let action, !isStarting else { return }
        isStarting = true
        Task {
            if await start(action) {
                text = ""
                focused = false
            }
            isStarting = false
        }
    }
}
