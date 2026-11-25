import Foundation

public struct TimerContents: Codable, Equatable, Sendable {
    public var version = 1
    public var timers: [TimerDefinition]
    public var runs: [TimerRun]

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
            return TimerContents()
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
