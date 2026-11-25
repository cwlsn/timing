import Foundation

public enum RingState: Sendable, Equatable { case scheduled, countdown, paused, alerting }

public struct RingInfo: Sendable, Equatable {
    public var state: RingState
    /// When a countdown ends, if the system says.
    public var endsAt: Date?
    /// What a paused countdown has left, if the system says.
    public var remaining: TimeInterval?

    public init(_ state: RingState, endsAt: Date? = nil, remaining: TimeInterval? = nil) {
        self.state = state
        self.endsAt = endsAt
        self.remaining = remaining
    }
}

/// One countdown to hand to the system. The run lets ring buttons work without the store, which may be
/// unavailable before the phone's first unlock.
public struct RingRequest: Sendable, Equatable {
    public let run: TimerRun
    public let seconds: TimeInterval
    public var id: UUID { run.ringID }
}

public protocol TimerClient: Sendable {
    func authorize() async throws -> Bool
    func isDenied() -> Bool
    func rings() throws -> [UUID: RingInfo]
    func schedule(_ request: RingRequest) async throws
    func pause(_ id: UUID) throws
    func resume(_ id: UUID) throws
    func stop(_ id: UUID) throws
    func cancel(_ id: UUID) throws
}
