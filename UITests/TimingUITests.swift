import XCTest

@MainActor
final class TimingUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() async throws { continueAfterFailure = false }

    private func launch(_ extra: String...) {
        app.launchArguments = ["-uiTesting"] + extra
        app.launch()
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Waits for the countdown to tick, then for its digits to finish changing, so a screenshot never catches them halfway.
    private func settle(_ label: String) {
        let time = app.staticTexts["countdown-\(label)"]
        expectation(for: NSPredicate(format: "label != %@", time.label), evaluatedWith: time)
        waitForExpectations(timeout: 3)
        Thread.sleep(forTimeInterval: 0.7)
    }

    private func type(_ text: String) {
        let field = app.textFields["Quick start"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    private func quickStart(_ text: String) {
        type(text)
        app.buttons["Start timer"].tap()
    }

    private func tile(_ label: String) -> XCUIElement { app.buttons["tile-\(label)"] }
    private func category(_ name: String) -> XCUIElement { app.buttons["category-\(name)"] }
    private func open(_ name: String, line: UInt = #line) {
        reveal(name, line: line)
        category(name).tap()
        waitFor(app.navigationBars[name], line: line)
    }
    private func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        waitFor(app.textFields["Quick start"])
    }
    /// Large text can push it below the bar, where the grid has not made it yet.
    private func reveal(_ name: String, line: UInt = #line) {
        waitFor(app.textFields["Quick start"], line: line)
        for _ in 0..<6 where !(category(name).exists && category(name).isHittable) { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(category(name).isHittable, "category-\(name) not reachable", line: line)
    }
    /// Starting from a category goes back to the main screen.
    private func start(_ label: String, in name: String, line: UInt = #line) {
        open(name, line: line)
        waitFor(tile(label), line: line)
        tile(label).tap()
        waitFor(app.buttons["Stop \(label)"], line: line)
        XCTAssertFalse(app.navigationBars[name].exists, line: line)
    }
    private func waitFor(_ element: XCUIElement, _ timeout: TimeInterval = 5, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) missing", line: line)
    }
    private func waitGone(_ element: XCUIElement, line: UInt = #line) {
        XCTAssertTrue(element.waitForNonExistence(timeout: 5), "\(element) still there", line: line)
    }
    private func menu(_ element: XCUIElement, _ item: String) {
        waitFor(element)
        element.press(forDuration: 1.2)
        waitFor(app.buttons[item])
        app.buttons[item].firstMatch.tap()
    }

    func testQuickStartSavesOnlyLabelled() {
        launch("-empty")
        waitFor(app.staticTexts["No timers yet"])
        capture("empty")
        type("9m pasta")
        let preview = app.descendants(matching: .any)["quick-preview"]
        waitFor(preview)
        XCTAssertTrue(preview.label.contains("Starts and saves"), preview.label)
        capture("quick")
        app.buttons["Start timer"].tap()
        waitFor(app.buttons["Stop Pasta"])
        // Filed under what its label suggests.
        waitFor(category("Cooking"))
        quickStart("20m")
        waitFor(app.buttons["Stop Timer"])
        XCTAssertFalse(category("Other").exists)
        app.buttons["Stop Timer"].tap()
        waitGone(app.buttons["Stop Timer"])
        app.buttons["Stop Pasta"].tap()
        waitGone(app.buttons["Stop Pasta"])
        XCTAssertEqual(app.staticTexts["header"].label, "No timers running")
        open("Cooking")
        waitFor(tile("Pasta"))
    }

    func testThreeAtOnceAndTilesAlwaysStartAnother() {
        launch("-seed")
        for label in ["Rice", "Eggs", "Pasta"] { start(label, in: "Cooking") }
        // Two share a row and the third fills its own.
        let cards = ["Eggs", "Pasta", "Rice"].map { app.descendants(matching: .any).matching(identifier: "run-\($0)").firstMatch.frame }
        XCTAssertEqual(cards[0].minY, cards[1].minY, accuracy: 1)
        XCTAssertEqual(cards[0].width, cards[1].width, accuracy: 1)
        XCTAssertEqual(cards[0].height, cards[1].height, accuracy: 1)
        XCTAssertGreaterThan(cards[2].minY, cards[0].maxY)
        XCTAssertGreaterThan(cards[2].width, cards[0].width * 2)
        capture("three")
        XCTAssertEqual(category("Cooking").value as? String, "3 running")
        open("Cooking")
        tile("Pasta").tap()
        expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: app.buttons.matching(NSPredicate(format: "label == 'Stop Pasta'")))
        waitForExpectations(timeout: 5)
    }

    func testPauseHoldsTime() {
        launch("-seed")
        start("Tea", in: "Drinks")
        app.buttons["Pause Tea"].tap()
        waitFor(app.buttons["Resume Tea"])
        let time = app.staticTexts["countdown-Tea"]
        let held = time.label
        sleep(3)
        XCTAssertEqual(time.label, held)
        app.buttons["Resume Tea"].tap()
        waitFor(app.buttons["Pause Tea"])
        sleep(2)
        XCTAssertNotEqual(time.label, held)
    }

    func testRingAddRepeatStop() {
        launch("-empty")
        quickStart("3s eggs")
        waitFor(app.buttons["Repeat Eggs"], 8)
        XCTAssertEqual(app.staticTexts["header"].label, "Eggs is ringing")
        // Lets the header's old text finish fading out.
        Thread.sleep(forTimeInterval: 0.7)
        capture("ringing")
        app.buttons["Repeat Eggs"].tap()
        waitFor(app.buttons["Pause Eggs"])
        waitFor(app.buttons["Add 5m Eggs"], 8)
        app.buttons["Add 5m Eggs"].tap()
        waitFor(app.buttons["Pause Eggs"])
        XCTAssertTrue(["5:00", "4:59", "4:58"].contains(app.staticTexts["countdown-Eggs"].label), app.staticTexts["countdown-Eggs"].label)
        app.buttons["Stop Eggs"].tap()
        waitGone(app.buttons["Stop Eggs"])
    }

    func testCreateEditDelete() {
        launch()
        app.buttons["Add timer"].firstMatch.tap()
        waitFor(app.pickerWheels.firstMatch)
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "12 min")
        app.textFields["Label"].tap()
        app.textFields["Label"].typeText("Risotto\n")
        XCTAssertEqual(app.buttons["category-picker"].value as? String, "Cooking")
        capture("editor-new")
        app.buttons["Start"].tap()
        // It starts without another tap.
        waitFor(app.buttons["Stop Risotto"])
        open("Cooking")
        waitFor(tile("Risotto"))
        XCTAssertTrue(tile("Risotto").label.contains("12m"), tile("Risotto").label)
        menu(tile("Risotto"), "Edit")
        waitFor(app.pickerWheels.firstMatch)
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "2 min")
        app.segmentedControls.buttons["Repeat"].tap()
        app.buttons["Done"].firstMatch.tap()
        expectation(for: NSPredicate(format: "label CONTAINS '2m' AND NOT label CONTAINS '12m'"), evaluatedWith: tile("Risotto"))
        waitForExpectations(timeout: 5)
        menu(tile("Risotto"), "Delete")
        waitGone(tile("Risotto"))
        back()
        // The run keeps the length it started with.
        XCTAssertTrue(app.staticTexts["countdown-Risotto"].label.hasPrefix("11:"), app.staticTexts["countdown-Risotto"].label)
    }

    func testCategories() {
        launch()
        let names = ["Quick", "Cooking", "Baking", "Drinks", "Exercise", "Everyday"]
        for name in names { waitFor(category(name)) }
        XCTAssertFalse(category("Other").exists)
        capture("categories")
        open("Drinks")
        for label in ["Green tea", "Black tea", "Herbal tea", "French press"] { waitFor(tile(label)) }
        capture("category")
        app.buttons["add-Drinks"].tap()
        waitFor(app.pickerWheels.firstMatch)
        app.textFields["Label"].tap()
        app.textFields["Label"].typeText("Japan trip\n")
        // Made here, so it stays here whatever its label says.
        XCTAssertEqual(app.buttons["category-picker"].value as? String, "Drinks")
        app.buttons["Start"].tap()
        waitFor(app.buttons["Stop Japan trip"])
        open("Drinks")
        menu(tile("Japan trip"), "Edit")
        app.buttons["category-picker"].tap()
        app.buttons["From the label (Other)"].tap()
        XCTAssertEqual(app.buttons["category-picker"].value as? String, "Other")
        app.buttons["Done"].firstMatch.tap()
        waitGone(tile("Japan trip"))
        back()
        start("Japan trip", in: "Other")
        // Deleting the last one in a category goes back and hides it.
        open("Other")
        menu(tile("Japan trip"), "Delete")
        waitGone(app.navigationBars["Other"])
        waitGone(category("Other"))
    }

    func testStartersAndMostUsedFirst() {
        launch()
        open("Quick")
        for label in ["5 minutes", "10 minutes", "15 minutes"] { waitFor(tile(label)) }
        XCTAssertLessThan(tile("5 minutes").frame.minX, tile("15 minutes").frame.minX)
        capture("starters")
        back()
        start("15 minutes", in: "Quick")
        for _ in 0..<2 { start("Black tea", in: "Drinks") }
        // Nothing moves until the app is opened again.
        XCTAssertLessThan(category("Quick").frame.minX, category("Drinks").frame.minX)
        open("Quick")
        XCTAssertLessThan(tile("5 minutes").frame.minX, tile("15 minutes").frame.minX)
        back()
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        waitFor(category("Drinks"))
        let first = NSPredicate { [app] _, _ in
            MainActor.assumeIsolated { app.buttons["category-Drinks"].frame.minY < app.buttons["category-Cooking"].frame.minY }
        }
        expectation(for: first, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(category("Drinks").frame.minX, category("Cooking").frame.minX, accuracy: 1)
        capture("most-used")
        open("Quick")
        XCTAssertLessThan(tile("15 minutes").frame.minX, tile("5 minutes").frame.minX)
    }

    func testChooseIcon() {
        launch("-seed")
        open("Drinks")
        menu(tile("Tea"), "Edit")
        let chosen = app.buttons["icon-☕️"]
        waitFor(chosen)
        XCTAssertTrue(app.buttons["icon-🍵"].isSelected)
        chosen.tap()
        XCTAssertTrue(chosen.isSelected)
        capture("icon")
        app.buttons["Done"].firstMatch.tap()
        waitFor(tile("Tea"))
    }

    func testDenied() {
        launch("-denied")
        waitFor(app.staticTexts["Alarms are turned off"])
        quickStart("9m chowder")
        waitFor(app.alerts["Timer not changed"])
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(category("Other").exists)
        capture("denied")
    }

    func testWidgetGallery() {
        for (name, extra) in [("light", []), ("dark", ["-dark"])] {
            app.launchArguments = ["-uiTesting", "-widgets"] + extra
            app.launch()
            XCTAssertTrue(app.buttons["New timer"].firstMatch.waitForExistence(timeout: 5))
            sleep(1)
            capture("widgets-\(name)")
        }
    }

    func testScreenshots() {
        for (name, extra) in [("light", []), ("dark", ["-dark"]), ("large", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])] {
            app.launchArguments = ["-uiTesting", "-seed", "-running"] + extra
            app.launch()
            waitFor(app.buttons["Resume Sourdough"])
            reveal("Baking")
            XCTAssertEqual(category("Baking").value as? String, "1 paused")
            settle("Eggs")
            capture("main-\(name)")
            open("Cooking")
            sleep(1)
            capture("category-\(name)")
            back()
            app.buttons["Add timer"].firstMatch.tap()
            waitFor(app.pickerWheels.firstMatch)
            sleep(1)
            capture("editor-\(name)")
        }
    }
}
