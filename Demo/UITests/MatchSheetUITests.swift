import XCTest

/// Parcours de la feuille de match qu'un argument de lancement ne suffit pas à montrer.
final class MatchSheetUITests: XCTestCase {
    /// Un match touché dans le Score Center ouvre la feuille du SDK (navigation par défaut).
    @MainActor
    func testContestTapPushesMatchSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-scoreCenter", "2026-11-08"]
        app.launch()

        let match = app.buttons["Angers 0, Nice 2, terminé"]
        XCTAssertTrue(match.waitForExistence(timeout: 20))
        match.tap()

        XCTAssertTrue(app.navigationBars["Feuille de match"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Angers"].waitForExistence(timeout: 20))
        sleep(3)
        keepScreenshot("match-sheet-header-actions")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(match.waitForExistence(timeout: 5))
    }

    /// App UIKit : le Score Center dans une `UINavigationController` (racine `UIHostingController`,
    /// sans `NavigationStack`). Un match touché pousse la feuille dans cette pile, et « retour » y
    /// revient.
    @MainActor
    func testContestTapPushesMatchSheetInUIKitNavigationController() {
        let app = XCUIApplication()
        app.launchArguments = ["-uikitHost"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Hôte UIKit"].waitForExistence(timeout: 20))
        let match = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Danemark")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 20))
        match.tap()

        XCTAssertTrue(app.navigationBars["Feuille de match"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Norvège"].waitForExistence(timeout: 20))
        sleep(2)
        keepScreenshot("match-sheet-uikit-host")
        app.navigationBars["Feuille de match"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Hôte UIKit"].waitForExistence(timeout: 5))
        XCTAssertTrue(match.waitForExistence(timeout: 5))
    }

    /// Les compositions : le terrain sous les onglets, restés épinglés au défilement.
    @MainActor
    func testLineupsPitch() {
        let app = XCUIApplication()
        app.launchArguments = ["-contest", "54732603", "-tab", "lineups"]
        app.launch()

        XCTAssertTrue(app.staticTexts["4-2-3-1"].waitForExistence(timeout: 20))
        // Défile d'un tiers d'écran : les onglets s'épinglent, le terrain entier dessous.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)),
            withVelocity: .slow,
            thenHoldForDuration: 0.5
        )
        sleep(3)
        keepScreenshot("match-sheet-lineups")
    }

    @MainActor
    private func keepScreenshot(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
