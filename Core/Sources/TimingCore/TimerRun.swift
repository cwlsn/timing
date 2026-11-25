import CryptoKit
import Foundation

/// One countdown in progress. It carries a copy of its timer, so it outlives edits and deletion.
public struct TimerRun: Codable, Hashable, Identifiable, Sendable {
    public enum Phase: Codable, Hashable, Sendable {
        case running(endsAt: Date)
        case paused(remaining: TimeInterval)
        case ringing
    }

    public let id: UUID
    public let timer: TimerDefinition
    /// Goes up each time the countdown is replaced, so a late tap on an old ring does nothing.
    public var generation: Int
    /// Length of the current countdown, for progress.
    public var total: TimeInterval
    public var phase: Phase

    public init(id: UUID = UUID(), timer: TimerDefinition, generation: Int = 0, total: TimeInterval, phase: Phase) {
        self.id = id
        self.timer = timer
        self.generation = generation
        self.total = total
        self.phase = phase
    }

    /// The system alarm for the current countdown.
    public var ringID: UUID { RunSlot.id(for: id, generation: generation) }

    public func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .running(let endsAt): max(0, endsAt.timeIntervalSince(now))
        case .paused(let remaining): max(0, remaining)
        case .ringing: 0
        }
    }

    public func fractionLeft(at now: Date) -> Double {
        total > 0 ? min(1, remaining(at: now) / total) : 0
    }

    /// Ringing first, then soonest to ring, then paused.
    static func comesFirst(_ a: TimerRun, _ b: TimerRun) -> Bool {
        func key(_ run: TimerRun) -> (Int, TimeInterval, String) {
            switch run.phase {
            case .ringing: (0, 0, run.id.uuidString)
            case .running(let endsAt): (1, endsAt.timeIntervalSinceReferenceDate, run.id.uuidString)
            case .paused(let remaining): (2, remaining, run.id.uuidString)
            }
        }
        return key(a) < key(b)
    }
}

public enum RunSlot {
    /// Two alternating IDs are enough: one ring sounds while its successor counts down.
    public static func id(for run: UUID, generation: Int) -> UUID {
        let b = Array(SHA256.hash(data: Data("\(run.uuidString)-run-\(generation % 2)".utf8)).prefix(16))
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    public static func all(for run: UUID) -> [UUID] { [id(for: run, generation: 0), id(for: run, generation: 1)] }
}
