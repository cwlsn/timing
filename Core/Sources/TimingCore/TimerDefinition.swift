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
    /// Chosen picture, or `nil` to follow the label.
    public var icon: String?
    /// How many times it has been started.
    public var useCount: Int

    public init(id: UUID = UUID(), label: String = TimerDefinition.defaultLabel, seconds: Int, tone: String? = nil,
                ringButton: RingButton = .addTime, addMinutes: Int = 5,
                icon: String? = nil, useCount: Int = 0) {
        self.id = id
        self.label = label
        self.seconds = seconds
        self.tone = tone
        self.ringButton = ringButton
        self.addMinutes = addMinutes
        self.icon = icon
        self.useCount = useCount
    }

    /// Files from before icons and use counts must still load.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        label = try values.decode(String.self, forKey: .label)
        seconds = try values.decode(Int.self, forKey: .seconds)
        tone = try values.decodeIfPresent(String.self, forKey: .tone)
        ringButton = try values.decode(RingButton.self, forKey: .ringButton)
        addMinutes = try values.decode(Int.self, forKey: .addMinutes)
        icon = try values.decodeIfPresent(String.self, forKey: .icon)
        useCount = try values.decodeIfPresent(Int.self, forKey: .useCount) ?? 0
    }

    /// Waiting on first launch. Fixed IDs, so widgets and Siri agree on them before the first save.
    public static let starters = [(5, "☕️"), (10, "🍳"), (15, "🔥")].enumerated().map { index, starter in
        TimerDefinition(id: UUID(uuid: (0x71, 0x4D, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, UInt8(index + 1))),
                        label: DurationText.spoken(starter.0 * 60), seconds: starter.0 * 60, icon: starter.1)
    }

    public var displayIcon: String { icon ?? TimerIcon.suggestion(for: label) ?? TimerIcon.fallback }

    /// Whether the label only repeats the length.
    public var isNamedForLength: Bool { label == DurationText.spoken(seconds) }

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
