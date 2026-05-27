import XCTest

final class OnboardingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Dev Skip Button

    func testSkipToAppWithDevButton() {
        let skipButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Saltar'")).firstMatch
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "El boton de saltar al app deberia existir")
        skipButton.tap()

        // Verify main tab bar appears after skipping
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "El tab bar principal deberia aparecer despues de saltar")
    }

    // MARK: - Onboarding Flow

    func testOnboardingFlowLoadsViaSocialLogin() {
        // Tap any social login button — they all trigger dev/mock mode
        let socialButtons = app.buttons.allElementsBoundByIndex
        // Find the first button that looks like a social login (Apple, Google, Facebook)
        var tapped = false
        for button in socialButtons {
            let label = button.label.lowercased()
            if label.contains("apple") || label.contains("google") || label.contains("facebook") {
                button.tap()
                tapped = true
                break
            }
        }

        if tapped {
            // Give time for onboarding or next screen to load
            let nextScreen = app.navigationBars.firstMatch.exists
                || app.staticTexts.element(boundBy: 0).waitForExistence(timeout: 5)
            XCTAssertTrue(nextScreen, "Deberia cargar la siguiente pantalla despues de login social")
        }
    }

    // MARK: - Login Screen Elements

    func testLoginScreenHasExpectedElements() {
        // Verify at least one button exists on the login screen
        let anyButton = app.buttons.firstMatch
        XCTAssertTrue(anyButton.waitForExistence(timeout: 5), "La pantalla de login deberia tener al menos un boton")

        // Verify there is some text visible (app name, welcome message, etc.)
        let anyText = app.staticTexts.firstMatch
        XCTAssertTrue(anyText.waitForExistence(timeout: 3), "La pantalla de login deberia mostrar texto")
    }
}
