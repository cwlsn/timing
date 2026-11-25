import Foundation

public enum DurationText {
    /// "1h 5m", "9m", "1m 30s".
    public static func short(_ seconds: Int) -> String {
        let parts = [(seconds / 3600, "h"), (seconds / 60 % 60, "m"), (seconds % 60, "s")]
        let text = parts.filter { $0.0 > 0 }.map { "\($0.0)\($0.1)" }.joined(separator: " ")
        return text.isEmpty ? "0s" : text
    }

    /// "4:12" or "1:05:00". Rounded up, so it reads zero only when the timer is done.
    public static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        let tail = String(format: "%02d", seconds % 60)
        guard seconds >= 3600 else { return "\(seconds / 60):\(tail)" }
        return "\(seconds / 3600):\(String(format: "%02d", seconds / 60 % 60)):\(tail)"
    }

    /// "4 min", "1 hr 5 min", "under a minute".
    public static func rough(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded(.up))
        guard minutes > 1 else { return "under a minute" }
        guard minutes >= 60 else { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) hr" : "\(minutes / 60) hr \(minutes % 60) min"
    }

    /// "5 minutes", "1 hour 30 minutes".
    public static func spoken(_ seconds: Int) -> String {
        [(seconds / 3600, "hour"), (seconds / 60 % 60, "minute"), (seconds % 60, "second")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
            .joined(separator: " ")
    }
}
