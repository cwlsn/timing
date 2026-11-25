import AppIntents
import Foundation
import OSLog
import TimingCore

private let logger = Logger(subsystem: "com.cwlsn.timing", category: "intents")

/// iOS runs these in the app's process, launching it if needed. A failure is logged and leaves the timer
/// as it was, so the person can tap again.
private func performRing(_ name: String, _ snapshot: String, _ work: @MainActor (TimerRun) async throws -> Void) async {
    do { try await work(RunSnapshot.decode(snapshot)) } catch { logger.error("\(name, privacy: .public) failed: \(error, privacy: .public)") }
}

struct AddTimeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Time"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var snapshot: String

    init() {}
    init(snapshot: String) { self.snapshot = snapshot }

    func perform() async throws -> some IntentResult {
        await performRing("Add Time", snapshot) { try await Services.model.addTime($0) }
        return .result()
    }
}

struct RepeatTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Repeat"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var snapshot: String

    init() {}
    init(snapshot: String) { self.snapshot = snapshot }

    func perform() async throws -> some IntentResult {
        await performRing("Repeat", snapshot) { try await Services.model.repeat($0) }
        return .result()
    }
}

struct StopTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var snapshot: String

    init() {}
    init(snapshot: String) { self.snapshot = snapshot }

    func perform() async throws -> some IntentResult {
        await performRing("Stop", snapshot) { try await Services.model.stop($0) }
        return .result()
    }
}

struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var snapshot: String

    init() {}
    init(snapshot: String) { self.snapshot = snapshot }

    func perform() async throws -> some IntentResult {
        await performRing("Pause", snapshot) { try await Services.model.pause($0.id) }
        return .result()
    }
}

struct ResumeTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var snapshot: String

    init() {}
    init(snapshot: String) { self.snapshot = snapshot }

    func perform() async throws -> some IntentResult {
        await performRing("Resume", snapshot) { try await Services.model.resume($0.id) }
        return .result()
    }
}
