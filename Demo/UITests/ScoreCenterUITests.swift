import XCTest

/// Parcours de la démo qu'un argument de lancement ne suffit pas à ouvrir.
final class ScoreCenterUITests: XCTestCase {
    /// « Classement » d'un bloc ouvre le classement de sa saison dans une feuille ; la capture est
    /// gardée dans le résultat du test.
    @MainActor
    func testStandingsSheetOpensFromBlock() {
        let app = XCUIApplication()
        app.launchArguments = ["-scoreCenter", "2026-11-08"] + Self.appearance
        app.launch()

        let button = app.buttons["Classement — Ligue 1"]
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        button.tap()

        XCTAssertTrue(app.staticTexts["Ligue 1 2026/2027"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Fermer"].exists)
        // Le temps que les logos arrivent.
        sleep(3)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "score-center-standings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Apparence forcée, transmise par la variable d'environnement `DEMO_APPEARANCE` du test.
    private static var appearance: [String] {
        ProcessInfo.processInfo.environment["DEMO_APPEARANCE"].map { ["-appearance", $0] } ?? []
    }
}
