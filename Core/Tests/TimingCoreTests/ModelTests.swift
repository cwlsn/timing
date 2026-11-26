import Foundation
import Synchronization
import Testing
@testable import TimingCore

private struct Boom: Error {}

private final class FakeClient: TimerClient {
    struct State {
        var rings: [UUID: RingInfo] = [:]
        var log: [String] = []
        var fails: Set<String> = []
        var denied = false
    }
    let state = Mutex(State())

    private func act(_ name: String, _ body: (inout State) -> Void) throws {
        try state.withLock {
            if $0.fails.contains(name) { throw Boom() }
            $0.log.append(name)
            body(&$0)
        }
    }
    func fail(_ names: String...) { state.withLock { $0.fails = Set(names) } }
    func set(_ id: UUID, _ info: RingInfo?) { state.withLock { $0.rings[id] = info } }
    var log: [String] { state.withLock { $0.log } }
    func clearLog() { state.withLock { $0.log = [] } }

    func authorize() async throws -> Bool { !isDenied() }
    func isDenied() -> Bool { state.withLock { $0.denied } }
    func rings() throws -> [UUID: RingInfo] { state.withLock { $0.rings } }
    func schedule(_ r: RingRequest) async throws { try act("schedule") { $0.rings[r.id] = RingInfo(.countdown) } }
    func pause(_ id: UUID) throws { try act("pause") { $0.rings[id] = RingInfo(.paused) } }
    func resume(_ id: UUID) throws { try act("resume") { $0.rings[id] = RingInfo(.countdown) } }
    func stop(_ id: UUID) throws { try act("stop") { $0.rings[id] = nil } }
    func cancel(_ id: UUID) throws { try act("cancel") { $0.rings[id] = nil } }
}

@MainActor
struct ModelTests {
    private let client = FakeClient()
    private let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString)/timers.json")
    private let clock = Clock()
    private final class Clock { var now = Date(timeIntervalSinceReferenceDate: 1_000_000) }
    private let pasta = TimerDefinition(label: "Pasta", seconds: 540)

    /// Starts with no timers, unlike a first launch.
    private func make() -> TimerModel {
        if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) { try? TimerFile(url: url).save(TimerContents()) }
        return first()
    }

    private func first() -> TimerModel {
        TimerModel(client: client, file: TimerFile(url: url), now: { [clock] in clock.now })
    }

    private func ringing(_ model: TimerModel) async throws -> TimerRun {
        let run = try await model.start(pasta)
        client.set(run.ringID, RingInfo(.alerting))
        try await model.reconcile()
        return try #require(model.runs.first)
    }

    @Test func startSavesOnlyWhenAsked() async throws {
        let model = make()
        try await model.start(pasta)
        #expect(model.timers.isEmpty && model.runs.count == 1)
        try await model.start(pasta, saving: true)
        #expect(model.timers.map(\.id) == [pasta.id] && model.timers[0].useCount == 1)
        #expect(make().runs.count == 2)
    }

    @Test func failedStartChangesNothing() async throws {
        let model = make()
        client.fail("schedule")
        await #expect(throws: Boom.self) { try await model.start(pasta, saving: true) }
        #expect(model.timers.isEmpty && model.runs.isEmpty)
        client.state.withLock { $0.denied = true; $0.fails = [] }
        await #expect(throws: TimerModelError.permissionDenied) { try await model.start(pasta) }
        #expect(model.permissionDenied)
    }

    @Test func failedWriteCancelsTheCountdown() async throws {
        let model = first()
        // A file where the folder should be.
        try Data().write(to: url.deletingLastPathComponent())
        await #expect(throws: (any Error).self) { try await model.start(pasta) }
        #expect(try client.rings().isEmpty && model.runs.isEmpty)
    }

    @Test func pauseKeepsTimeAndResumeContinues() async throws {
        let model = make()
        let run = try await model.start(pasta)
        clock.now += 100
        try await model.pause(run.id)
        #expect(model.runs[0].phase == .paused(remaining: 440))
        clock.now += 1000
        try await model.resume(run.id)
        #expect(model.runs[0].phase == .running(endsAt: clock.now + 440))
    }

    @Test func ringButtonsScheduleBeforeStopping() async throws {
        let model = make()
        let run = try await ringing(model)
        client.clearLog()
        try await model.addTime(run)
        #expect(client.log == ["schedule", "stop"])
        #expect(model.runs[0].remaining(at: clock.now) == 300 && model.runs[0].generation == 1)
        // A second tap on the same ring.
        try await model.addTime(run)
        #expect(client.log == ["schedule", "stop"])
        // A late Stop for it.
        try await model.stop(run)
        #expect(model.runs.count == 1)
    }

    @Test func repeatRunsTheWholeLengthForManyRounds() async throws {
        let model = make()
        var run = try await ringing(model)
        for round in 1...5 {
            try await model.repeat(run)
            run = model.runs[0]
            #expect(run.generation == round && run.remaining(at: clock.now) == 540)
            #expect(try client.rings().count == 1)
            client.set(run.ringID, RingInfo(.alerting))
        }
    }

    @Test func failedRepeatLeavesItRinging() async throws {
        let model = make()
        let run = try await ringing(model)
        client.fail("schedule")
        await #expect(throws: Boom.self) { try await model.repeat(run) }
        #expect(try client.rings()[run.ringID]?.state == .alerting && model.runs == [run])
        client.fail("stop")
        await #expect(throws: Boom.self) { try await model.repeat(run) }
        #expect(try client.rings().count == 1 && model.runs == [run])
    }

    @Test func addTimeWhileRunningOrPaused() async throws {
        let model = make()
        _ = try await model.start(pasta)
        clock.now += 40
        try await model.addTime(model.runs[0])
        #expect(model.runs[0].remaining(at: clock.now) == 800)
        try await model.pause(model.runs[0].id)
        try await model.addTime(model.runs[0])
        #expect(model.runs[0].phase == .paused(remaining: 1100))
        #expect(try client.rings()[model.runs[0].ringID]?.state == .paused)
    }

    @Test func buttonsWorkFromTheirCopyWhenTheFileIsUnreadable() async throws {
        let run = try await ringing(make())
        let saved = try Data(contentsOf: url)
        try Data("locked".utf8).write(to: url)
        let model = make()
        #expect(model.storageFailed)
        try await model.repeat(run)
        #expect(try client.rings()[RunSlot.id(for: run.id, generation: 1)]?.state == .countdown)
        #expect(try Data(contentsOf: url) == Data("locked".utf8))
        // Readable again, in a new process, with an old generation on file.
        try saved.write(to: url)
        let later = make()
        try await later.reconcile()
        #expect(later.runs.count == 1 && later.runs[0].generation == 1)
        #expect(later.runs[0].phase == .running(endsAt: clock.now + 540))
    }

    @Test func unreadableFileCancelsNothing() async throws {
        _ = try await make().start(pasta)
        try Data("bad".utf8).write(to: url)
        await #expect(throws: TimerModelError.storageUnavailable) { try await make().reconcile() }
        #expect(try client.rings().count == 1)
    }

    @Test func reconcileFollowsTheSystem() async throws {
        let model = make()
        let run = try await model.start(pasta)
        client.set(run.ringID, RingInfo(.paused, remaining: 200))
        client.set(UUID(), RingInfo(.countdown))
        try await model.reconcile()
        #expect(model.runs[0].phase == .paused(remaining: 200))
        #expect(try client.rings().count == 1)
        client.set(run.ringID, RingInfo(.countdown, endsAt: clock.now + 150))
        try await model.reconcile()
        #expect(model.runs[0].phase == .running(endsAt: clock.now + 150))
        client.set(run.ringID, RingInfo(.countdown, endsAt: clock.now + 150.3))
        try await model.reconcile()
        #expect(model.runs[0].phase == .running(endsAt: clock.now + 150))
        client.set(run.ringID, nil)
        try await model.reconcile()
        #expect(model.runs.isEmpty)
    }

    @Test func reconcileFinishesAnInterruptedRepeat() async throws {
        let model = make()
        let run = try await ringing(model)
        let next = RunSlot.id(for: run.id, generation: 1)
        client.set(next, RingInfo(.countdown, endsAt: clock.now + 540))
        try await model.reconcile()
        #expect(try Array(client.rings().keys) == [next])
        #expect(model.runs[0].generation == 1)
    }

    @Test func editingOrDeletingNeverTouchesARun() async throws {
        let model = make()
        try await model.start(pasta, saving: true)
        var edited = pasta
        edited.seconds = 60
        edited.label = "  "
        try await model.save(edited)
        #expect(model.timers[0].label == "Timer" && model.runs[0].timer == pasta)
        try await model.delete(pasta.id)
        #expect(model.timers.isEmpty && model.runs.count == 1)
    }

    @Test func mostUsedComeFirst() async throws {
        let model = make()
        let timers = ["A", "B", "C"].map { TimerDefinition(label: $0, seconds: 60) }
        for timer in timers { try await model.save(timer) }
        for label in ["C", "C", "B"] { try await model.start(timers.first { $0.label == label }!) }
        #expect(model.timersByUse.map(\.label) == ["C", "B", "A"])
        #expect(model.timers.map(\.label) == ["A", "B", "C"])
        // A one-time run, a failed start and an edit count for nothing.
        try await model.start(TimerDefinition(seconds: 5))
        client.fail("schedule")
        await #expect(throws: Boom.self) { try await model.start(timers[0]) }
        var edited = timers[2]
        edited.label = "D"
        try await model.save(edited)
        #expect(make().timersByUse.map(\.useCount) == [2, 1, 0] && model.timersByUse[0].label == "D")
    }

    @Test func runsAreByUrgency() async throws {
        let model = make()
        for seconds in [300, 100, 200] { try await model.start(TimerDefinition(label: "\(seconds)", seconds: seconds)) }
        #expect(model.runs.map(\.timer.label) == ["100", "200", "300"])
        try await model.pause(model.runs[0].id)
        client.set(model.runs[1].ringID, RingInfo(.alerting))
        try await model.reconcile()
        #expect(model.runs.map(\.timer.label) == ["300", "200", "100"])
    }

    @Test func firstLaunchHasStartersAndPresetsAndDeletingThemIsFinal() async throws {
        let model = first()
        #expect(model.timers.prefix(3).map(\.seconds) == [300, 600, 900])
        #expect(model.timers.count == 3 + TimerDefinition.presets.count)
        #expect(Set(model.timers.map(\.id)).count == model.timers.count)
        #expect(TimerContents(timers: model.timers).categoriesByUse == [.quick, .cooking, .baking, .drinks, .exercise, .everyday])
        for timer in model.timers { try await model.delete(timer.id) }
        #expect(first().timers.isEmpty)
    }

    @Test func oldFileLoadsAndGainsStartersAndPresets() throws {
        let old = #"{"version":1,"timers":[{"id":"6B0E5A0C-6D5B-4C0B-9A55-0F4C3B7B1E11","label":"Tea","seconds":180,"ringButton":"addTime","addMinutes":5}],"runs":[]}"#
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(old.utf8).write(to: url)
        let model = first()
        #expect(!model.storageFailed && model.timers.prefix(4).map(\.label) == ["Tea", "5 minutes", "10 minutes", "15 minutes"])
        #expect(model.timers.prefix(4).map(\.displayIcon) == ["🍵", "⏱️", "⏲️", "⌛️"])
        #expect(model.timers[0].category == nil && model.timers[0].displayCategory == .drinks)
        #expect(model.timers.count == 4 + TimerDefinition.presets.count)
    }

    /// Starters from before categories join Quick. A chosen icon is kept, and a deleted one stays deleted.
    @Test func startersFromVersionTwoJoinQuick() throws {
        var kept = TimerDefinition.starters[0]
        kept.category = nil
        kept.icon = "☕️"
        var chosen = TimerDefinition.starters[1]
        chosen.category = nil
        chosen.icon = "🥚"
        var contents = TimerContents(timers: [kept, chosen])
        contents.version = 2
        try TimerFile(url: url).save(contents)
        let model = first()
        #expect(model.timers.prefix(2).map(\.displayIcon) == ["⏱️", "🥚"])
        #expect(model.timers.prefix(2).map(\.category) == [.quick, .quick])
        #expect(!model.timers.contains { $0.id == TimerDefinition.starters[2].id })
        #expect(model.timers.count == 2 + TimerDefinition.presets.count)
    }

    @Test func categoriesFollowTheLabelUntilChosenAndSortByUse() async throws {
        let model = make()
        let tea = TimerDefinition(label: "Tea", seconds: 180)
        var plank = TimerDefinition(label: "Plank", seconds: 60)
        let odd = TimerDefinition(label: "Japan trip", seconds: 60)
        for timer in [tea, plank, odd] { try await model.save(timer) }
        #expect(model.timers.map(\.displayCategory) == [.drinks, .exercise, .other])
        try await model.startSaved(plank.id)
        #expect(TimerContents(timers: model.timers).categoriesByUse == [.exercise, .drinks, .other])
        plank.category = .everyday
        try await model.save(plank)
        #expect(TimerContents(timers: model.timers).categoriesByUse == [.everyday, .drinks, .other])
    }

    @Test func lengthNamesFollowTheLength() async throws {
        let model = first()
        var five = model.timers[0]
        five.seconds = 420
        try await model.save(five)
        #expect(model.timers[0].label == "7 minutes")
    }

    @Test func startSavedAlwaysStartsAnother() async throws {
        let model = make()
        try await model.save(pasta)
        async let first: Void = model.startSaved(pasta.id)
        async let second: Void = model.startSaved(pasta.id)
        _ = try await (first, second)
        #expect(model.runs.count == 2 && model.timers[0].useCount == 2)
        await #expect(throws: TimerModelError.unknownTimer) { try await model.startSaved(UUID()) }
    }

    @Test func soonestIsClosestToRinging() async throws {
        let model = make()
        for seconds in [300, 100, 200] { try await model.start(TimerDefinition(label: "\(seconds)", seconds: seconds)) }
        try await model.pause(model.runs[0].id)
        let contents = TimerContents(timers: [], runs: model.runs)
        #expect(contents.soonest(after: clock.now)?.timer.label == "200")
        #expect(contents.soonest(after: clock.now + 350) == nil)
    }

    @Test func stopEndsIt() async throws {
        let model = make()
        let run = try await ringing(model)
        try await model.stop(run)
        #expect(try client.rings().isEmpty && model.runs.isEmpty && make().runs.isEmpty)
    }
}
