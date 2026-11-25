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
        launch()
        waitFor(app.staticTexts["No timers yet"])
        capture("empty")
        type("9m pasta")
        let preview = app.descendants(matching: .any)["quick-preview"]
        waitFor(preview)
        XCTAssertTrue(preview.label.contains("Starts and saves"), preview.label)
        capture("quick")
        app.buttons["Start timer"].tap()
        waitFor(tile("Pasta"))
        waitFor(app.buttons["Stop Pasta"])
        quickStart("20m")
        waitFor(app.buttons["Stop Timer"])
        XCTAssertFalse(tile("Timer").exists)
        app.buttons["Stop Timer"].tap()
        waitGone(app.buttons["Stop Timer"])
        app.buttons["Stop Pasta"].tap()
        waitGone(app.buttons["Stop Pasta"])
        XCTAssertTrue(tile("Pasta").exists)
        XCTAssertEqual(app.staticTexts["header"].label, "No timers running")
    }

    func testThreeAtOnceAndNoDuplicates() {
        launch("-seed")
        for label in ["Rice", "Eggs", "Pasta"] {
            waitFor(tile(label))
            tile(label).tap()
            waitFor(app.buttons["Stop \(label)"])
        }
        tile("Pasta").tap()
        tile("Pasta").tap()
        XCTAssertEqual(app.buttons.matching(identifier: "Stop Pasta").count, 1)
        capture("three")
        menu(tile("Pasta"), "Start another")
        expectation(for: NSPredicate(format: "count == 2"), evaluatedWith: app.buttons.matching(NSPredicate(format: "label == 'Stop Pasta'")))
        waitForExpectations(timeout: 5)
    }

    func testPauseHoldsTime() {
        launch("-seed")
        waitFor(tile("Tea"))
        tile("Tea").tap()
        waitFor(app.buttons["Pause Tea"])
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
        launch()
        quickStart("3s eggs")
        waitFor(app.buttons["Repeat Eggs"], 8)
        XCTAssertEqual(app.staticTexts["header"].label, "Eggs is ringing")
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
        app.textFields["Label"].typeText("Rice\n")
        capture("editor-new")
        app.buttons["Add"].tap()
        waitFor(tile("Rice"))
        XCTAssertTrue(tile("Rice").label.contains("12m"), tile("Rice").label)
        tile("Rice").tap()
        waitFor(app.buttons["Stop Rice"])
        menu(tile("Rice"), "Edit")
        waitFor(app.pickerWheels.firstMatch)
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "2 min")
        app.segmentedControls.buttons["Repeat"].tap()
        app.buttons["Done"].firstMatch.tap()
        expectation(for: NSPredicate(format: "label CONTAINS '2m' AND NOT label CONTAINS '12m'"), evaluatedWith: tile("Rice"))
        waitForExpectations(timeout: 5)
        // The run keeps the length it started with.
        XCTAssertTrue(app.staticTexts["countdown-Rice"].label.hasPrefix("11:"), app.staticTexts["countdown-Rice"].label)
        menu(tile("Rice"), "Delete")
        waitGone(tile("Rice"))
        XCTAssertTrue(app.buttons["Stop Rice"].exists)
    }

    func testReorder() {
        launch("-seed")
        menu(tile("Rice"), "Reorder")
        let handles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder'"))
        waitFor(handles.firstMatch)
        capture("reorder")
        handles.element(boundBy: 0).press(forDuration: 0.6, thenDragTo: handles.element(boundBy: 2))
        app.buttons["Done"].firstMatch.tap()
        waitFor(tile("Eggs"))
        XCTAssertTrue(tile("Eggs").frame.minY < tile("Rice").frame.minY || tile("Eggs").frame.minX < tile("Rice").frame.minX)
    }

    func testDenied() {
        launch("-denied")
        waitFor(app.staticTexts["Alarms are turned off"])
        quickStart("9m pasta")
        waitFor(app.alerts["Timer not changed"])
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(tile("Pasta").exists)
        capture("denied")
    }

    func testScreenshots() {
        for (name, extra) in [("light", []), ("dark", ["-dark"]), ("large", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])] {
            app.launchArguments = ["-uiTesting", "-seed", "-running"] + extra
            app.launch()
            waitFor(app.buttons["Resume Sourdough"])
            sleep(1)
            capture("main-\(name)")
            app.buttons["Add timer"].firstMatch.tap()
            waitFor(app.pickerWheels.firstMatch)
            sleep(1)
            capture("editor-\(name)")
        }
    }
}
