import XCTest

/// L'écran « Briques » (cartes, top 5, liste mixte, ligne maison, routeur) et les contrôleurs UIKit.
final class BlocksUITests: XCTestCase {
    /// Une carte touchée passe par le routeur, qui laisse le SDK ouvrir la feuille de match.
    @MainActor
    func testCardRoutesToSDKMatchSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-blocks"]
        app.launch()

        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Danemark")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        sleep(3)
        keepScreenshot("blocks-top")
        card.tap()
        XCTAssertTrue(app.navigationBars["Feuille de match"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Norvège"].waitForExistence(timeout: 20))
        app.navigationBars["Feuille de match"].buttons.element(boundBy: 0).tap()
        let log = app.staticTexts["router-log"]
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertTrue(log.label.contains("feuille du SDK"))
    }

    /// Une équipe touchée dans le classement : l'app la prend en charge (`.handled`).
    @MainActor
    func testTeamHandledByHostRouter() {
        let app = XCUIApplication()
        app.launchArguments = ["-blocks"]
        app.launch()

        let lens = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Lens")).firstMatch
        XCTAssertTrue(lens.waitForExistence(timeout: 20))
        lens.tap()
        XCTAssertTrue(app.alerts["Équipe 22103"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
    }

    /// Plus bas : la liste de l'app (ses rubriques, puis les matchs du jour) et la ligne maison.
    @MainActor
    func testMixedListAndCustomRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-blocks"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Mes rubriques"].waitForExistence(timeout: 20))
        app.swipeUp(velocity: .slow)
        sleep(2)
        keepScreenshot("blocks-list")
        let custom = app.staticTexts["Ligne maison · IdalgoComponents"]
        for _ in 0..<6 where !custom.isHittable { app.swipeUp(velocity: .slow) }
        sleep(2)
        keepScreenshot("blocks-custom-row")
    }

    /// App UIKit : la feuille de match en `IdalgoMatchSheetViewController` ; une équipe touchée,
    /// le routeur de l'app pousse le classement en `IdalgoStandingsViewController`.
    @MainActor
    func testUIKitControllers() {
        let app = XCUIApplication()
        app.launchArguments = ["-uikitControllers"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Feuille de match"].waitForExistence(timeout: 20))
        // Arsenal dans le classement de l'avant-match.
        let arsenal = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Arsenal, 15 points")).firstMatch
        XCTAssertTrue(arsenal.waitForExistence(timeout: 20))
        sleep(2)
        keepScreenshot("uikit-match-sheet")
        arsenal.tap()
        XCTAssertTrue(app.navigationBars["Classement"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Premier League 2026/2027"].waitForExistence(timeout: 20))
        sleep(3)
        keepScreenshot("uikit-standings")
    }

    @MainActor
    private func keepScreenshot(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
