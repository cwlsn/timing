import Foundation

/// Groups saved timers on the main screen. A timer without one follows its label.
public enum TimerCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick, cooking, baking, drinks, exercise, everyday, other

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .quick: "Quick"
        case .cooking: "Cooking"
        case .baking: "Baking"
        case .drinks: "Drinks"
        case .exercise: "Exercise"
        case .everyday: "Everyday"
        case .other: "Other"
        }
    }

    public var icon: String {
        switch self {
        case .quick: "⏱️"
        case .cooking: "🍳"
        case .baking: "🧁"
        case .drinks: "☕️"
        case .exercise: "🏃"
        case .everyday: "🏠"
        case .other: "⭐️"
        }
    }

    public static func suggestion(for label: String) -> TimerCategory? { TimerIcon.match(label)?.category }
}

extension TimerDefinition {
    public var displayCategory: TimerCategory { category ?? TimerCategory.suggestion(for: label) ?? .other }

    /// Ready on first launch, one category at a time. Fixed IDs, so widgets and Siri agree on them before the first save.
    public static let presets: [TimerDefinition] = {
        let groups: [(TimerCategory, [(String, Int, String)])] = [
            (.cooking, [("Soft eggs", 360, "🥚"), ("Hard eggs", 600, "🥚"), ("Pasta", 600, "🍝"),
                        ("Rice", 1080, "🍚"), ("Potatoes", 1200, "🥔"), ("Steak", 480, "🥩")]),
            (.baking, [("Preheat", 900, "🔥"), ("Cookies", 660, "🍪"), ("Pizza", 720, "🍕"),
                       ("Muffins", 1200, "🧁"), ("Cake", 2100, "🎂"), ("Bread", 2400, "🍞")]),
            (.drinks, [("Green tea", 120, "🍵"), ("Black tea", 240, "🍵"), ("Herbal tea", 360, "🌿"), ("French press", 240, "☕️")]),
            (.exercise, [("Plank", 60, "🏋️"), ("Rest", 90, "💤"), ("Stretch", 300, "🧘"), ("Run", 1800, "🏃")]),
            (.everyday, [("Focus", 1500, "🎯"), ("Nap", 1200, "😴"), ("Laundry", 2700, "🧺"), ("Parking", 3600, "🅿️")]),
        ]
        return groups.enumerated().flatMap { group, entry in
            entry.1.enumerated().map { index, preset in
                TimerDefinition(id: presetID(group: UInt8(group + 1), index: UInt8(index + 1)), label: preset.0,
                                seconds: preset.1, icon: preset.2, category: entry.0)
            }
        }
    }()

    static func presetID(group: UInt8, index: UInt8) -> UUID {
        UUID(uuid: (0x71, 0x4D, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, group, index))
    }
}

extension TimerContents {
    /// Categories with at least one timer, most used first. Equal ones keep their usual order.
    public var categoriesByUse: [TimerCategory] {
        let uses = Dictionary(grouping: timers, by: \.displayCategory).mapValues { $0.reduce(0) { $0 + $1.useCount } }
        return TimerCategory.allCases.enumerated()
            .compactMap { offset, category in uses[category].map { (category, $0, offset) } }
            .sorted { ($1.1, $0.2) < ($0.1, $1.2) }
            .map(\.0)
    }
}
