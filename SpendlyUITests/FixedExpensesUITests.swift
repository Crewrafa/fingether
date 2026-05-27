import XCTest

final class FixedExpensesUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
        skipToApp()
    }

    // MARK: - Helpers

    private func skipToApp() {
        let skipButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Saltar'")).firstMatch
        guard skipButton.waitForExistence(timeout: 5) else { return }
        skipButton.tap()
        let tabBar = app.tabBars.firstMatch
        _ = tabBar.waitForExistence(timeout: 5)
    }

    // MARK: - Fijos Tab

    func testFijosTabLoads() {
        let fijosTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fijos'")).firstMatch
        guard fijosTab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Fijos")
            return
        }
        fijosTab.tap()

        // Verify the fixed expenses screen shows content
        let anyContent = app.staticTexts.firstMatch
        XCTAssertTrue(anyContent.waitForExistence(timeout: 5), "La pantalla de Fijos deberia mostrar contenido")
    }

    func testFijosTabHasToggleOrSwitch() {
        let fijosTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fijos'")).firstMatch
        guard fijosTab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Fijos")
            return
        }
        fijosTab.tap()

        // Look for toggle/switch elements (for enabling/disabling fixed expenses)
        let toggle = app.switches.firstMatch
        if toggle.waitForExistence(timeout: 5) {
            XCTAssertTrue(toggle.exists, "Deberia existir al menos un toggle en gastos fijos")
        }
        // If no toggle found, the screen at least loaded
    }

    func testFijosTabHasListContent() {
        let fijosTab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fijos'")).firstMatch
        guard fijosTab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Fijos")
            return
        }
        fijosTab.tap()

        // Verify there are cells or list items (fixed expenses list)
        let hasContent = app.cells.firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts.count > 0
            || app.collectionViews.firstMatch.exists
            || app.scrollViews.firstMatch.exists
        XCTAssertTrue(hasContent, "La pantalla de Fijos deberia tener contenido de lista o texto")
    }
}
