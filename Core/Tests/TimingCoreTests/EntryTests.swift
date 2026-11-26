import Foundation
import Testing
@testable import TimingCore

struct EntryTests {
    @Test(arguments: [
        ("9m", 540, ""), ("90s", 90, ""), ("1h30", 5400, ""), ("1h 5m 10s", 3910, ""), ("1h5m10s", 3910, ""),
        ("9 min pasta", 540, "pasta"), ("pasta 9m", 540, "pasta"), ("1:30", 90, ""), ("1:30:00", 5400, ""),
        ("9", 540, ""), ("9 pasta", 540, "pasta"), ("pasta 9", 540, "pasta"), ("2 eggs 6m", 360, "2 eggs"),
        ("1 hour 5 minutes roast beef", 3900, "roast beef"), ("5m30 tea", 330, "tea"), ("90:00", 5400, ""),
        ("23:59:59", 86_399, ""),
    ])
    func reads(_ text: String, _ seconds: Int, _ label: String) {
        #expect(DurationEntry.parse(text) == .init(seconds: seconds, label: label))
    }

    @Test(arguments: ["", "pasta", "0m", "24h", "99999999999999999999m", "99999999999999999999", "1:75", "1:60:00"])
    func refuses(_ text: String) { #expect(DurationEntry.parse(text).seconds == nil) }

    private let template = TimerDefinition(seconds: 600, tone: "glass.caf", ringButton: .repeat)

    @Test func labelledSavesAndBareDoesNot() {
        guard case .startAndSave(let pasta)? = DurationEntry.action(for: "9m pasta", saved: [], template: template) else {
            Issue.record("not saved"); return
        }
        #expect(pasta.label == "Pasta" && pasta.seconds == 540 && pasta.tone == "glass.caf" && pasta.ringButton == .repeat)
        guard case .startOnce(let bare)? = DurationEntry.action(for: "9m", saved: [], template: template) else {
            Issue.record("saved"); return
        }
        #expect(bare.label == "Timer" && bare.seconds == 540)
        #expect(DurationEntry.action(for: "pasta", saved: [], template: template) == nil)
    }

    @Test func savedNamesMatchIgnoringCaseAndKeepTheirLength() {
        let saved = TimerDefinition(label: "Pasta", seconds: 600)
        #expect(DurationEntry.action(for: "PASTA", saved: [saved], template: template) == .startSaved(saved))
        var once = saved
        once.seconds = 540
        #expect(DurationEntry.action(for: "9m pasta", saved: [saved], template: template) == .startSaved(once))
        let numbered = TimerDefinition(label: "Step 2", seconds: 60)
        #expect(DurationEntry.action(for: "step 2", saved: [numbered], template: template) == .startSaved(numbered))
    }

    @Test func text() {
        #expect(DurationText.short(3900) == "1h 5m")
        #expect(DurationText.short(90) == "1m 30s")
        #expect(DurationText.countdown(252) == "4:12")
        #expect(DurationText.countdown(0.2) == "0:01")
        #expect(DurationText.countdown(3900) == "1:05:00")
        #expect(DurationText.rough(30) == "under a minute")
        #expect(DurationText.rough(200) == "4 min")
        #expect(DurationText.rough(3900) == "1 hr 5 min")
    }

    @Test func iconsFollowWords() {
        let icon = { TimerDefinition(label: $0, seconds: 1).displayIcon }
        #expect(icon("Soft eggs") == "🥚" && icon("Pancakes") == "🥞" && icon("Sourdough") == "🍞")
        // Parts of words are not words.
        #expect(icon("Steam") == TimerIcon.fallback && icon("Japan trip") == TimerIcon.fallback)
        #expect(Set(TimerIcon.choices).count == TimerIcon.choices.count)
    }

    /// A preset's label agrees with what it was given, so renaming one lands it somewhere sensible.
    @Test func presetsMatchTheirWords() {
        for preset in TimerDefinition.presets {
            #expect(TimerIcon.suggestion(for: preset.label) == preset.icon, "\(preset.label)")
            #expect(TimerCategory.suggestion(for: preset.label) == preset.category, "\(preset.label)")
            #expect(TimerIcon.choices.contains(preset.displayIcon), "\(preset.label)")
        }
        for starter in TimerDefinition.starters { #expect(TimerIcon.choices.contains(starter.displayIcon)) }
        #expect(TimerCategory.suggestion(for: "9m pasta") == .cooking && TimerCategory.suggestion(for: "Japan trip") == nil)
    }

    @Test func spectrumKeepsWhiteTextReadable() {
        for step in 0...100 {
            let spectrum = SpectrumPalette(fractionLeft: Double(step) / 100)
            #expect(spectrum.deep.contrastWithWhite >= 4.5 && spectrum.bright.contrastWithWhite >= 4.5, "\(step)")
        }
    }

    @Test func defaultsRememberLastChoices() throws {
        let store = try #require(UserDefaults(suiteName: UUID().uuidString))
        let defaults = NewTimerDefaults(store: store)
        #expect(defaults.blank().ringButton == .addTime && defaults.blank().addMinutes == 5)
        defaults.remember(TimerDefinition(seconds: 1, tone: "glass.caf", ringButton: .repeat, addMinutes: 2))
        let blank = defaults.blank()
        #expect(blank.tone == "glass.caf" && blank.ringButton == .repeat && blank.addMinutes == 2)
    }
}
