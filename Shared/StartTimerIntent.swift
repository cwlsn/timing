import AppIntents
import Foundation
import TimingCore

struct TimerEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    static let defaultQuery = TimerQuery()

    let id: UUID
    let label: String
    let seconds: Int

    init(_ timer: TimerDefinition) { (id, label, seconds) = (timer.id, timer.displayLabel, timer.seconds) }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(label)", subtitle: "\(DurationText.short(seconds))")
    }
}

/// Reads the app group copy, because widgets and Siri ask from outside the app.
struct TimerQuery: EntityStringQuery {
    private func all() -> [TimerEntity] { ((try? TimerFile.shared?.load())?.timers ?? []).map(TimerEntity.init) }

    func entities(for identifiers: [UUID]) async throws -> [TimerEntity] { all().filter { identifiers.contains($0.id) } }
    func entities(matching string: String) async throws -> [TimerEntity] {
        all().filter { $0.label.localizedCaseInsensitiveContains(string) }
    }
    func suggestedEntities() async throws -> [TimerEntity] { all() }
}

struct StartTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription("Starts one of your saved timers.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    static var parameterSummary: some ParameterSummary { Summary("Start \(\.$timer)") }

    @Parameter(title: "Timer") var timer: TimerEntity

    init() {}
    init(timer: TimerEntity) { self.timer = timer }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = await Services.model
        do { try await model.startSaved(timer.id) } catch { throw StartFailure(error) }
        return .result(dialog: "\(timer.label), \(DurationText.short(timer.seconds)).")
    }
}

private enum StartFailure: Error, CustomLocalizedStringResourceConvertible {
    case permission, unknown, other

    init(_ error: any Error) {
        self = switch error {
        case TimerModelError.permissionDenied: .permission
        case TimerModelError.unknownTimer: .unknown
        default: .other
        }
    }

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .permission: "Allow Timing to set alarms in Settings, then try again."
        case .unknown: "That timer no longer exists."
        case .other: "The timer could not start. Open Timing and try again."
        }
    }
}

/// For the control, which may not have a timer chosen yet.
struct StartChosenTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Chosen Timer"
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Timer") var timer: TimerEntity?

    init() {}
    init(timer: TimerEntity?) { self.timer = timer }

    func perform() async throws -> some IntentResult {
        if let timer { _ = try await StartTimerIntent(timer: timer).perform() }
        return .result()
    }
}
