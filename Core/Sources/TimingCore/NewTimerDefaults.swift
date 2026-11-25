import Foundation

/// What new timers start with: the last tone and ring button chosen, so they rarely need setting twice.
public struct NewTimerDefaults {
    private static let toneKey = "lastTone", buttonKey = "lastRingButton", minutesKey = "lastAddMinutes"
    private let store: UserDefaults?

    /// `nil` remembers nothing.
    public init(store: UserDefaults?) { self.store = store }

    public func remember(_ timer: TimerDefinition) {
        store?.set(timer.tone, forKey: Self.toneKey)
        store?.set(timer.ringButton.rawValue, forKey: Self.buttonKey)
        store?.set(timer.addMinutes, forKey: Self.minutesKey)
    }

    public func blank() -> TimerDefinition {
        var timer = TimerDefinition(seconds: 600)
        timer.tone = store?.string(forKey: Self.toneKey)
        if let button = store?.string(forKey: Self.buttonKey).flatMap(RingButton.init) { timer.ringButton = button }
        if let minutes = store?.object(forKey: Self.minutesKey) as? Int { timer.addMinutes = minutes }
        return timer.normalized
    }
}
