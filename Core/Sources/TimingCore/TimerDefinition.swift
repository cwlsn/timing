import Foundation

public enum RingButton: String, Codable, CaseIterable, Sendable { case addTime, `repeat` }

public struct TimerDefinition: Codable, Hashable, Identifiable, Sendable {
    public static let defaultLabel = "Timer"
    public static let secondsRange = 1...86_399
    public static let addMinutesRange = 1...60

    public let id: UUID
    public var label: String
    public var seconds: Int
    /// Bundled sound file name, or `nil` for the system default.
    public var tone: String?
    /// iOS allows one button beside Stop on the ring screen.
    public var ringButton: RingButton
    public var addMinutes: Int

    public init(id: UUID = UUID(), label: String = TimerDefinition.defaultLabel, seconds: Int, tone: String? = nil,
                ringButton: RingButton = .addTime, addMinutes: Int = 5) {
        self.id = id
        self.label = label
        self.seconds = seconds
        self.tone = tone
        self.ringButton = ringButton
        self.addMinutes = addMinutes
    }

    public var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultLabel : trimmed
    }

    var normalized: TimerDefinition {
        var timer = self
        timer.label = displayLabel
        timer.seconds = min(max(seconds, Self.secondsRange.lowerBound), Self.secondsRange.upperBound)
        timer.addMinutes = min(max(addMinutes, Self.addMinutesRange.lowerBound), Self.addMinutesRange.upperBound)
        return timer
    }
}
