import AlarmKit
import AppIntents
import SwiftUI

@main
struct TimingApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() { Services.updateShortcuts = { TimingShortcuts.updateAppShortcutParameters() } }

    var body: some Scene {
        WindowGroup {
            TimersView(model: Services.model)
                .tint(Color.accentText)
                .preferredColorScheme(Services.forcesDark ? .dark : nil)
                .task {
                    #if DEBUG
                    if Services.isSeeded { await Services.seed() }
                    if Services.isUITesting {
                        while !Task.isCancelled {
                            try? await Services.model.reconcile()
                            try? await Task.sleep(for: .seconds(0.25))
                        }
                    }
                    #endif
                    for await _ in AlarmManager.shared.alarmUpdates { try? await Services.model.reconcile() }
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { Task { try? await Services.model.reconcile() } }
        }
    }
}

struct TimingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTimerIntent(), phrases: [
            "Start \(\.$timer) in \(.applicationName)",
            "Start a timer in \(.applicationName)",
        ], shortTitle: "Start Timer", systemImageName: "timer")
    }
}
