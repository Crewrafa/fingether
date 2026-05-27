import XCTest

final class NavigationUITests: XCTestCase {
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

    // MARK: - Tab Bar Exists

    func testTabBarAppearsWithFiveTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "El tab bar deberia existir")

        let tabButtons = app.tabBars.buttons.allElementsBoundByIndex
        XCTAssertGreaterThanOrEqual(tabButtons.count, 5, "Deberian existir al menos 5 pestanas")
    }

    // MARK: - Navigate Each Tab

    func testGastosTabNavigates() {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Gastos'")).firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Gastos")
            return
        }
        tab.tap()
        // Verify screen loaded — any element visible
        let content = app.staticTexts.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "La pantalla Gastos deberia cargar")
    }

    func testFijosTabNavigates() {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Fijos'")).firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Fijos")
            return
        }
        tab.tap()
        let content = app.staticTexts.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "La pantalla Fijos deberia cargar")
    }

    func testYoNosotrosTabNavigates() {
        // This tab could be "Yo", "Nosotros", or "Yo/Nosotros"
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Yo' OR label CONTAINS[c] 'Nosotros'")).firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Yo/Nosotros")
            return
        }
        tab.tap()
        let content = app.staticTexts.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "La pantalla Yo/Nosotros deberia cargar")
    }

    func testMetasTabNavigates() {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Metas'")).firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Metas")
            return
        }
        tab.tap()
        let content = app.staticTexts.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "La pantalla Metas deberia cargar")
    }

    func testMasTabNavigates() {
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Mas' OR label CONTAINS[c] 'Más'")).firstMatch
        guard tab.waitForExistence(timeout: 5) else {
            XCTFail("No se encontro la pestana Mas")
            return
        }
        tab.tap()
        let content = app.staticTexts.firstMatch
        XCTAssertTrue(content.waitForExistence(timeout: 5), "La pantalla Mas deberia cargar")
    }

    // MARK: - Round Trip Navigation

    func testNavigateAllTabsSequentially() {
        let tabNames = ["Gastos", "Fijos", "Yo", "Metas", "Mas"]

        for name in tabNames {
            let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
            if tab.waitForExistence(timeout: 3) {
                tab.tap()
                // Brief wait to ensure no crash
                let loaded = app.staticTexts.firstMatch.waitForExistence(timeout: 3)
                    || app.buttons.firstMatch.waitForExistence(timeout: 2)
                XCTAssertTrue(loaded, "La pestana \(name) deberia cargar sin crash")
            }
        }
    }
}
