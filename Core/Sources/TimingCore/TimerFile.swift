import Foundation

public struct TimerContents: Codable, Equatable, Sendable {
    /// 2 added the starter timers.
    public static let currentVersion = 2
    public var version = Self.currentVersion
    public var timers: [TimerDefinition]
    public var runs: [TimerRun]

    /// Most used first. Equal ones keep the order they were added.
    public var byUse: [TimerDefinition] {
        timers.enumerated().sorted { ($1.element.useCount, $0.offset) < ($0.element.useCount, $1.offset) }.map(\.element)
    }

    /// The running timer closest to ringing, for the Dynamic Island.
    public func soonest(after now: Date) -> TimerRun? {
        runs.compactMap { run -> (TimerRun, Date)? in
            guard case .running(let endsAt) = run.phase, endsAt > now else { return nil }
            return (run, endsAt)
        }
        .min { $0.1 < $1.1 }?.0
    }

    /// Adds the starters once. Deleting them later is final.
    func migrated() -> TimerContents {
        guard version < 2 else { return self }
        var contents = self
        contents.timers += TimerDefinition.starters.filter { starter in !timers.contains { $0.id == starter.id } }
        contents.version = Self.currentVersion
        return contents
    }

    public init(timers: [TimerDefinition] = [], runs: [TimerRun] = []) {
        self.timers = timers
        self.runs = runs
    }
}

/// Saved timers and runs. The app keeps one as its store and one in the app group for widgets.
public struct TimerFile: Sendable {
    private let url: URL
    public init(url: URL) { self.url = url }

    /// A missing file is empty; an unreadable one throws so timers are never mistaken for deleted.
    public func load() throws -> TimerContents {
        do {
            return try JSONDecoder().decode(TimerContents.self, from: Data(contentsOf: url))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            var empty = TimerContents()
            empty.version = 0
            return empty
        }
    }

    public func save(_ contents: TimerContents) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        try JSONEncoder().encode(contents).write(to: url, options: options)
    }

    /// Returns whether anything changed, so widgets are only reloaded when they need to be.
    public func publish(_ contents: TimerContents) throws -> Bool {
        if let current = try? load(), current == contents, FileManager.default.fileExists(atPath: url.path) { return false }
        try save(contents)
        return true
    }
}
