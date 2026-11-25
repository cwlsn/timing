import AppIntents
import Foundation
import OSLog
import TimingCore
import WidgetKit

/// Live objects shared by the app's screens and the intents iOS runs in the app's process.
@MainActor
enum Services {
    static let client: any TimerClient = makeClient()
    static let model = TimerModel(client: client, file: TimerFile(url: storeURL), publish: publish)

    /// UI tests always start fresh and save nothing.
    static let preferences: UserDefaults? = isUITesting ? nil : .standard
    static let newTimers = NewTimerDefaults(store: preferences)

    #if DEBUG
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
    static let forcesDark = ProcessInfo.processInfo.arguments.contains("-dark")
    static let isSeeded = isUITesting && ProcessInfo.processInfo.arguments.contains("-seed")

    /// A kitchen's worth of timers for tests and screenshots.
    static func seed() async {
        let timers = [
            TimerDefinition(label: "Rice", seconds: 720), TimerDefinition(label: "Eggs", seconds: 390),
            TimerDefinition(label: "Pasta", seconds: 540), TimerDefinition(label: "Pancakes", seconds: 90, ringButton: .repeat),
            TimerDefinition(label: "Tea", seconds: 180), TimerDefinition(label: "Sourdough", seconds: 2700),
        ]
        for timer in timers { try? await model.save(timer) }
        if ProcessInfo.processInfo.arguments.contains("-running") {
            for (index, left) in [(0, 498.0), (1, 78.0), (5, 2520.0)] {
                guard let run = try? await model.start(timers[index]) else { continue }
                (client as? PreviewTimerClient)?.move(run.ringID, left: left)
            }
            try? await model.reconcile()
            if let bread = model.runs.first(where: { $0.timer.label == "Sourdough" }) { try? await model.pause(bread.id) }
        }
    }
    #else
    static let isUITesting = false
    static let forcesDark = false
    #endif

    private static func makeClient() -> any TimerClient {
        #if DEBUG
        if isUITesting { return PreviewTimerClient(denied: ProcessInfo.processInfo.arguments.contains("-denied")) }
        #endif
        return AlarmKitClient()
    }

    private static func publish(_ contents: TimerContents) {
        #if !targetEnvironment(simulator)
        // Test timers must not reach the widgets on a real phone.
        guard !isUITesting else { return }
        #endif
        do {
            let before = try? TimerFile.shared?.load().timers
            guard try TimerFile.shared?.publish(contents) == true else { return }
            WidgetCenter.shared.reloadAllTimelines()
            if before != contents.timers { updateShortcuts() }
        } catch {
            Logger(subsystem: "com.cwlsn.timing", category: "widget").error("Publish failed: \(error, privacy: .public)")
        }
    }

    /// Set by the app, which alone knows its Siri phrases.
    static var updateShortcuts: () -> Void = {}

    private static var storeURL: URL {
        isUITesting
            ? URL.temporaryDirectory.appending(path: "uitest-\(UUID().uuidString).json")
            : URL.applicationSupportDirectory.appending(path: "timers.json")
    }
}

extension TimerFile {
    /// In the container the app and its widgets share.
    static let shared = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String ?? "")
        .map { TimerFile(url: $0.appending(path: "timers.json")) }
}

#if DEBUG
import Synchronization

/// The iOS 27 simulator refuses alarm permission, so UI tests use this in place of AlarmKit. It really counts down.
final class PreviewTimerClient: TimerClient {
    private enum Entry { case running(Date), paused(TimeInterval) }
    private let entries = Mutex<[UUID: Entry]>([:])
    private let denied: Bool
    init(denied: Bool) { self.denied = denied }

    func authorize() async throws -> Bool { !denied }
    func isDenied() -> Bool { denied }
    func rings() throws -> [UUID: RingInfo] {
        entries.withLock { $0.mapValues { entry in
            switch entry {
            case .running(let end): end <= .now ? RingInfo(.alerting) : RingInfo(.countdown, endsAt: end)
            case .paused(let left): RingInfo(.paused, remaining: left)
            }
        } }
    }
    func schedule(_ request: RingRequest) async throws { entries.withLock { $0[request.id] = .running(.now + request.seconds) } }
    func pause(_ id: UUID) throws {
        entries.withLock { if case .running(let end)? = $0[id] { $0[id] = .paused(max(0, end.timeIntervalSinceNow)) } }
    }
    func resume(_ id: UUID) throws {
        entries.withLock { if case .paused(let left)? = $0[id] { $0[id] = .running(.now + left) } }
    }
    func stop(_ id: UUID) throws { entries.withLock { $0[id] = nil } }
    func cancel(_ id: UUID) throws { entries.withLock { $0[id] = nil } }
    func move(_ id: UUID, left: TimeInterval) { entries.withLock { $0[id] = .running(.now + left) } }
}
#endif
