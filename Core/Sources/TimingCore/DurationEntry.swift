import Foundation

/// Reads a typed line such as "9m pasta", "eggs 6:30" or "pasta".
public enum DurationEntry {
    public struct Result: Equatable, Sendable {
        public var seconds: Int?
        public var label: String
    }

    public enum Action: Equatable, Sendable {
        case startAndSave(TimerDefinition)
        /// An existing timer, perhaps with another length this once.
        case startSaved(TimerDefinition)
        case startOnce(TimerDefinition)

        public var timer: TimerDefinition {
            switch self { case .startAndSave(let timer), .startSaved(let timer), .startOnce(let timer): timer }
        }
    }

    /// `template` supplies the tone and ring button for a new timer.
    public static func action(for text: String, saved: [TimerDefinition], template: TimerDefinition) -> Action? {
        let entry = parse(text)
        if !entry.label.isEmpty, var match = saved.first(where: { same($0.label, entry.label) }) {
            if let seconds = entry.seconds { match.seconds = seconds }
            return .startSaved(match)
        }
        // A saved name may itself hold a number, such as "Step 2".
        let whole = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = saved.first(where: { same($0.label, whole) }) { return .startSaved(match) }
        guard let seconds = entry.seconds else { return nil }
        var timer = template
        timer.seconds = seconds
        timer.label = entry.label.isEmpty ? TimerDefinition.defaultLabel : entry.label.prefix(1).uppercased() + entry.label.dropFirst()
        return entry.label.isEmpty ? .startOnce(timer) : .startAndSave(timer)
    }

    public static func parse(_ text: String) -> Result {
        let words = text.split { $0.isWhitespace || $0 == "," }.map(String.init)
        var label: [String] = []
        var total: Int?
        var isDurationEnd = false
        var index = 0
        while index < words.count {
            let word = words[index].lowercased()
            let next = index + 1 < words.count ? words[index + 1].lowercased() : nil
            // Durations written in several words must be together: "1h 5m 10s".
            let canExtend = total == nil || isDurationEnd
            if canExtend, let value = Int(word), let next, let factor = unit(next) {
                total = add(total, value, factor)
                isDurationEnd = true
                index += 2
            } else if canExtend, let value = compact(word) {
                total = add(total, value, 1)
                isDurationEnd = true
                index += 1
            } else {
                label.append(words[index])
                isDurationEnd = false
                index += 1
            }
        }
        // A lone number at either end means minutes.
        if total == nil {
            if let first = label.first, let minutes = minutes(first) {
                total = minutes
                label.removeFirst()
            } else if let last = label.last, let minutes = minutes(last) {
                total = minutes
                label.removeLast()
            }
        }
        let valid = total.flatMap { TimerDefinition.secondsRange.contains($0) ? $0 : nil }
        return Result(seconds: valid, label: label.joined(separator: " "))
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Saturates, so a huge number is out of range rather than a crash.
    private static func add(_ total: Int?, _ value: Int, _ factor: Int) -> Int {
        (total ?? 0) + min(value, 100_000) * factor
    }

    private static func minutes(_ word: String) -> Int? {
        guard word.allSatisfy(\.isASCIIDigit), let value = Int(word) else { return nil }
        return add(nil, value, 60)
    }

    private static func unit(_ word: String) -> Int? {
        switch word {
        case "s", "sec", "secs", "second", "seconds": 1
        case "m", "min", "mins", "minute", "minutes": 60
        case "h", "hr", "hrs", "hour", "hours": 3600
        default: nil
        }
    }

    /// One word: "1h30", "1h5m10s", "9min", "1:30", "1:30:00".
    private static func compact(_ word: String) -> Int? {
        func number(_ text: Substring?) -> Int { text.map { min(Int($0) ?? 100_000, 100_000) } ?? 0 }
        if let match = word.wholeMatch(of: /(?:(\d+):)?(\d{1,3}):([0-5]\d)/) {
            if match.1 != nil, number(match.2) > 59 { return nil }
            return number(match.1) * 3600 + number(match.2) * 60 + number(match.3)
        }
        if let match = word.wholeMatch(of: /(\d+)h([0-5]?\d)/) { return number(match.1) * 3600 + number(match.2) * 60 }
        if let match = word.wholeMatch(of: /(\d+)m([0-5]?\d)/) { return number(match.1) * 60 + number(match.2) }
        guard let match = word.wholeMatch(of: /(?:(\d+)(?:h|hrs?|hours?))?(?:(\d+)(?:m|mins?|minutes?))?(?:(\d+)(?:s|secs?|seconds?))?/),
              match.1 != nil || match.2 != nil || match.3 != nil else { return nil }
        return number(match.1) * 3600 + number(match.2) * 60 + number(match.3)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
