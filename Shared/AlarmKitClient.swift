import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI
import TimingCore

struct RingMetadata: AlarmMetadata {
    /// The run as the buttons need it.
    var snapshot: String
    var label: String

    init(run: TimerRun) throws {
        snapshot = try RunSnapshot.encode(run)
        label = run.timer.displayLabel
    }
}

enum RunSnapshot {
    static func encode(_ run: TimerRun) throws -> String { String(decoding: try JSONEncoder().encode(run), as: UTF8.self) }
    static func decode(_ text: String) throws -> TimerRun { try JSONDecoder().decode(TimerRun.self, from: Data(text.utf8)) }
}

struct AlarmKitClient: TimerClient {
    func authorize() async throws -> Bool {
        try await AlarmManager.shared.requestAuthorization() == .authorized
    }

    func isDenied() -> Bool { AlarmManager.shared.authorizationState == .denied }

    func rings() throws -> [UUID: RingInfo] {
        // Alarm has no end time, but its Live Activity does.
        let modes = Dictionary(Activity<AlarmAttributes<RingMetadata>>.activities.map {
            ($0.content.state.alarmID, $0.content.state.mode)
        }, uniquingKeysWith: { $1 })
        return try AlarmManager.shared.alarms.reduce(into: [:]) { result, alarm in
            let state: RingState = switch alarm.state {
            case .scheduled: .scheduled
            case .countdown: .countdown
            case .paused: .paused
            case .alerting: .alerting
            @unknown default: .scheduled
            }
            var info = RingInfo(state)
            // The two can disagree for a moment, so a time counts only in the same state.
            switch (state, modes[alarm.id]) {
            case (.countdown, .countdown(let countdown)?): info.endsAt = countdown.fireDate
            case (.paused, .paused(let paused)?):
                info.remaining = max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)
            default: break
            }
            result[alarm.id] = info
        }
    }

    func pause(_ id: UUID) throws { try AlarmManager.shared.pause(id: id) }
    func resume(_ id: UUID) throws { try AlarmManager.shared.resume(id: id) }
    func stop(_ id: UUID) throws { try AlarmManager.shared.stop(id: id) }
    func cancel(_ id: UUID) throws { try AlarmManager.shared.cancel(id: id) }

    func schedule(_ request: RingRequest) async throws {
        let timer = request.run.timer
        let metadata = try RingMetadata(run: request.run)
        // Always a second button: iOS 27.2 can show nothing for a later ring with only Stop.
        let button: AlarmButton, intent: any LiveActivityIntent
        switch timer.ringButton {
        case .addTime:
            button = AlarmButton(text: "Add \(timer.addMinutes)m", textColor: .white, systemImageName: "plus")
            intent = AddTimeIntent(snapshot: metadata.snapshot)
        case .repeat:
            button = AlarmButton(text: "Repeat", textColor: .white, systemImageName: "repeat")
            intent = RepeatTimerIntent(snapshot: metadata.snapshot)
        }
        let title: LocalizedStringResource = "\(timer.displayLabel)"
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(
                alert: .init(title: title, secondaryButton: button, secondaryButtonBehavior: .custom),
                countdown: .init(title: title, pauseButton: AlarmButton(text: "Pause", textColor: .white, systemImageName: "pause.fill")),
                paused: .init(title: title, resumeButton: AlarmButton(text: "Resume", textColor: .white, systemImageName: "play.fill"))),
            metadata: metadata,
            tintColor: .accentBright)
        _ = try await AlarmManager.shared.schedule(id: request.id, configuration: .init(
            countdownDuration: .init(preAlert: request.seconds, postAlert: nil),
            attributes: attributes,
            stopIntent: StopTimerIntent(snapshot: metadata.snapshot),
            secondaryIntent: intent,
            sound: timer.tone.map { .named($0) } ?? .default))
    }
}
