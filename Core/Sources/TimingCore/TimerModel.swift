import Foundation
import Observation

public enum TimerModelError: Error, Equatable { case permissionDenied, storageUnavailable, unknownTimer }

@MainActor @Observable
public final class TimerModel {
    /// Saved timers, in the order the person arranged them.
    public private(set) var timers: [TimerDefinition] = []
    public private(set) var runs: [TimerRun] = []
    public private(set) var permissionDenied = false
    public private(set) var storageFailed = false

    @ObservationIgnored private let client: any TimerClient
    @ObservationIgnored private let file: TimerFile
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let publish: @MainActor (TimerContents) -> Void
    @ObservationIgnored private var loaded = false
    @ObservationIgnored private var operation: Task<Void, Never>?

    /// `publish` receives everything after each operation.
    public init(client: any TimerClient, file: TimerFile, now: @escaping @MainActor () -> Date = { .now },
                publish: @escaping @MainActor (TimerContents) -> Void = { _ in }) {
        self.client = client
        self.file = file
        self.now = now
        self.publish = publish
        try? loadIfNeeded()
    }

    public func isSaved(_ timer: TimerDefinition) -> Bool { timers.contains { $0.id == timer.id } }

    // MARK: Saved timers

    /// Adds or replaces a saved timer. Runs keep the copy they started with.
    public func save(_ timer: TimerDefinition) async throws {
        try await exclusively {
            try self.loadIfNeeded()
            var updated = self.timers
            if let index = updated.firstIndex(where: { $0.id == timer.id }) {
                updated[index] = timer.normalized
            } else {
                updated.append(timer.normalized)
            }
            try self.commit(timers: updated)
        }
    }

    public func delete(_ id: UUID) async throws {
        try await exclusively {
            try self.loadIfNeeded()
            try self.commit(timers: self.timers.filter { $0.id != id })
        }
    }

    /// Timers missing from `ids` keep their order at the end.
    public func reorder(_ ids: [UUID]) async throws {
        try await exclusively {
            try self.loadIfNeeded()
            let moved = ids.compactMap { id in self.timers.first { $0.id == id } }
            try self.commit(timers: moved + self.timers.filter { !ids.contains($0.id) })
        }
    }

    // MARK: Runs

    /// `saving` also keeps the timer. Nothing is saved unless the countdown starts.
    @discardableResult
    public func start(_ timer: TimerDefinition, saving: Bool = false) async throws -> TimerRun {
        try await exclusively {
            try self.loadIfNeeded()
            return try await self.begin(timer, saving: saving)
        }
    }

    /// For widgets, controls and Siri, which know only which timer was chosen. Never makes a duplicate.
    public func startSaved(_ id: UUID) async throws {
        try await exclusively {
            try self.loadIfNeeded()
            guard let timer = self.timers.first(where: { $0.id == id }) else { throw TimerModelError.unknownTimer }
            self.permissionDenied = self.client.isDenied()
            if !self.permissionDenied { try self.sync() }
            guard !self.runs.contains(where: { $0.timer.id == id }) else { return }
            _ = try await self.begin(timer, saving: false)
        }
    }

    public func pause(_ id: UUID) async throws {
        try await exclusively {
            try? self.loadIfNeeded()
            guard let index = self.runs.firstIndex(where: { $0.id == id }), case .running = self.runs[index].phase else { return }
            try self.client.pause(self.runs[index].ringID)
            self.runs[index].phase = .paused(remaining: self.runs[index].remaining(at: self.now()))
            self.runsChanged()
        }
    }

    public func resume(_ id: UUID) async throws {
        try await exclusively {
            try? self.loadIfNeeded()
            guard let index = self.runs.firstIndex(where: { $0.id == id }), case .paused(let left) = self.runs[index].phase else { return }
            try self.client.resume(self.runs[index].ringID)
            self.runs[index].phase = .running(endsAt: self.now().addingTimeInterval(left))
            self.runsChanged()
        }
    }

    /// `run` is the copy the button carries, used when the store cannot be read.
    public func addTime(_ run: TimerRun) async throws {
        try await exclusively { try await self.replaceCountdown(of: run) { $0 + TimeInterval(run.timer.addMinutes * 60) } }
    }

    public func `repeat`(_ run: TimerRun) async throws {
        try await exclusively { try await self.replaceCountdown(of: run) { _ in TimeInterval(run.timer.seconds) } }
    }

    public func stop(_ run: TimerRun) async throws {
        try await exclusively {
            try? self.loadIfNeeded()
            // A late Stop for an old ring must not end the countdown that replaced it.
            if let current = self.runs.first(where: { $0.id == run.id }), current.generation != run.generation { return }
            let rings = try self.client.rings()
            for slot in RunSlot.all(for: run.id) { if let ring = rings[slot] { try self.silence(slot, ring) } }
            self.runs.removeAll { $0.id == run.id }
            self.runsChanged()
        }
    }

    /// Brings runs and the system back into agreement after anything that happened while the app was away.
    public func reconcile() async throws {
        try await exclusively {
            try self.loadIfNeeded()
            self.permissionDenied = self.client.isDenied()
            guard !self.permissionDenied else { return }
            try self.sync()
        }
    }

    // MARK: Inside an operation

    private func begin(_ timer: TimerDefinition, saving: Bool) async throws -> TimerRun {
        let authorized = try await client.authorize()
        permissionDenied = !authorized
        guard authorized else { throw TimerModelError.permissionDenied }
        let timer = timer.normalized
        let seconds = TimeInterval(timer.seconds)
        var run = TimerRun(timer: timer, total: seconds, phase: .running(endsAt: now().addingTimeInterval(seconds)))
        try await client.schedule(RingRequest(run: run, seconds: seconds))
        run.phase = .running(endsAt: now().addingTimeInterval(seconds))
        do {
            try commit(timers: saving && !isSaved(timer) ? timers + [timer] : timers, runs: runs + [run])
        } catch {
            try? client.cancel(run.ringID)
            throw error
        }
        return run
    }

    /// Schedules the new countdown before ending the old one, so a failure leaves the timer as it was.
    private func replaceCountdown(of given: TimerRun, seconds: (TimeInterval) -> TimeInterval) async throws {
        let storeReadable = (try? loadIfNeeded()) != nil
        let known = runs.first { $0.id == given.id }
        // Not in a readable store means it was already stopped.
        guard var run = known ?? (storeReadable ? nil : given), run.generation == given.generation else { return }
        let old = run.ringID
        let rings = try client.rings()
        guard let ring = rings[old] else { return }

        let remaining = ring.state == .alerting ? 0 : run.remaining(at: now())
        let length = min(seconds(remaining), TimeInterval(TimerDefinition.secondsRange.upperBound))
        run.generation += 1
        run.total = length
        run.phase = .running(endsAt: now().addingTimeInterval(length))
        // Left by a half-finished attempt.
        if rings[run.ringID] != nil { try client.cancel(run.ringID) }
        try await client.schedule(RingRequest(run: run, seconds: length))
        do {
            if ring.state == .paused { try client.pause(run.ringID) }
            // It may have begun to ring in the meantime.
            if let current = try client.rings()[old] { try silence(old, current) }
        } catch {
            try? client.cancel(run.ringID)
            throw error
        }
        run.phase = ring.state == .paused ? .paused(remaining: length) : .running(endsAt: now().addingTimeInterval(length))
        runs.removeAll { $0.id == run.id }
        runs.append(run)
        runsChanged()
    }

    private func sync() throws {
        let rings = try client.rings()
        var updated: [TimerRun] = []
        var expected: Set<UUID> = []
        for var run in runs {
            let other = RunSlot.id(for: run.id, generation: run.generation + 1)
            switch (rings[run.ringID], rings[other]) {
            case (nil, nil): continue
            case (nil, _?): run.generation += 1
            case (_, nil): break
            case (let mine?, let theirs?):
                // Interrupted between scheduling a successor and ending the ring before it.
                if mine.state == .alerting, theirs.state != .alerting {
                    try client.stop(run.ringID)
                    run.generation += 1
                } else {
                    try silence(other, theirs)
                }
            }
            guard let ring = rings[run.ringID] else { continue }
            run.phase = phase(of: run, ring)
            run.total = max(run.total, run.remaining(at: now()))
            expected.insert(run.ringID)
            expected.formUnion(RunSlot.all(for: run.id))
            updated.append(run)
        }
        for id in rings.keys where !expected.contains(id) { try client.cancel(id) }
        updated.sort(by: TimerRun.comesFirst)
        guard updated != runs else { return }
        runs = updated
        runsChanged()
    }

    /// The system decides the state. Its times win when it gives them, and ours fill in when it does not.
    private func phase(of run: TimerRun, _ ring: RingInfo) -> TimerRun.Phase {
        switch ring.state {
        case .alerting:
            return .ringing
        case .paused:
            if case .paused(let left) = run.phase { return .paused(remaining: ring.remaining.map { settle($0, left) } ?? left) }
            return .paused(remaining: ring.remaining ?? run.remaining(at: now()))
        case .scheduled, .countdown:
            let ours: Date = switch run.phase {
            case .running(let endsAt): endsAt
            case .paused(let left): now().addingTimeInterval(left)
            case .ringing: now().addingTimeInterval(run.total)
            }
            guard let theirs = ring.endsAt else { return .running(endsAt: ours) }
            return .running(endsAt: Date(timeIntervalSinceReferenceDate: settle(
                theirs.timeIntervalSinceReferenceDate, ours.timeIntervalSinceReferenceDate)))
        }
    }

    /// Ignores differences too small to see, so the countdown never jitters.
    private func settle(_ theirs: TimeInterval, _ ours: TimeInterval) -> TimeInterval {
        abs(theirs - ours) < 0.5 ? ours : theirs
    }

    private func silence(_ id: UUID, _ ring: RingInfo) throws {
        if ring.state == .alerting { try client.stop(id) } else { try client.cancel(id) }
    }

    private func commit(timers: [TimerDefinition], runs: [TimerRun]? = nil) throws {
        let runs = (runs ?? self.runs).sorted(by: TimerRun.comesFirst)
        try file.save(TimerContents(timers: timers, runs: runs))
        self.timers = timers
        self.runs = runs
    }

    /// The system has already changed, so a failed write is not an error: reconciling repairs the file.
    private func runsChanged() {
        runs.sort(by: TimerRun.comesFirst)
        if loaded { try? file.save(TimerContents(timers: timers, runs: runs)) }
    }

    private func loadIfNeeded() throws {
        guard !loaded else { return }
        do {
            let contents = try file.load()
            timers = contents.timers
            // A ring button may have moved a run on while the file was unreadable.
            let newer = Dictionary(runs.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
            runs = contents.runs.map { newer[$0.id] ?? $0 }.sorted(by: TimerRun.comesFirst)
            loaded = true
            storageFailed = false
        } catch {
            storageFailed = true
            throw TimerModelError.storageUnavailable
        }
    }

    /// Runs operations one at a time so taps, ring buttons and reconciliation cannot interleave.
    private func exclusively<Value: Sendable>(_ work: @escaping @MainActor () async throws -> Value) async throws -> Value {
        let before = operation
        let task = Task { @MainActor in
            await before?.value
            defer { if self.loaded { self.publish(TimerContents(timers: self.timers, runs: self.runs)) } }
            return try await work()
        }
        operation = Task { _ = await task.result }
        return try await task.value
    }
}
