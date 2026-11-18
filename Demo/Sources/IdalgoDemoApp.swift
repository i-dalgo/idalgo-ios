import IdalgoKit
import SwiftUI

/// App de démo du SDK : quelques classements, le Score Center et la feuille de match. Arguments
/// de lancement : `-season <id>` ouvre un classement, `-scoreCenter <AAAA-MM-JJ|today>` le Score
/// Center à ce jour, `-liveDemo` le Score Center en direct simulé, `-contest <id>` une feuille de
/// match (`-tab info|actions|lineups|preview`), `-liveMatch` une feuille en direct simulé,
/// `-uikitHost` le Score Center dans une `UINavigationController` (app UIKit), `-blocks` l'écran
/// « Briques », `-uikitControllers` la feuille de match en `IdalgoMatchSheetViewController`,
/// `-theme idalgo|neutral|media|tokens` choisit le thème, `-appearance dark|light` force l'apparence.
@main
struct IdalgoDemoApp: App {
    init() {
        // API de production, ouverte : pas de clé en phase d'observation.
        Idalgo.configure(IdalgoConfiguration())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if DemoLaunch.uikitHost {
                    UIKitHostScreen().ignoresSafeArea()
                } else if DemoLaunch.uikitControllers {
                    UIKitControllersScreen().ignoresSafeArea()
                } else {
                    DemoHomeView(initialRoute: DemoLaunch.route)
                }
            }
            .preferredColorScheme(DemoLaunch.colorScheme)
        }
    }
}

/// Écran ouvert d'emblée et apparence, lus dans les arguments de lancement (captures, tests).
enum DemoLaunch {
    static var uikitHost: Bool { ProcessInfo.processInfo.arguments.contains("-uikitHost") }
    static var uikitControllers: Bool { ProcessInfo.processInfo.arguments.contains("-uikitControllers") }

    static var route: DemoRoute? {
        let defaults = UserDefaults.standard
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-blocks") { return .blocks }
        let tab = defaults.string(forKey: "tab").flatMap(MatchSheetTab.init(rawValue:))
        if arguments.contains("-liveMatch") { return .matchSheet(contest: DemoMatch.liveDemoContest, tab: tab, liveDemo: true) }
        if let contest = defaults.string(forKey: "contest") { return .matchSheet(contest: contest, tab: tab, liveDemo: false) }
        if arguments.contains("-liveDemo") { return .scoreCenter(date: nil, liveDemo: true) }
        if let date = defaults.string(forKey: "scoreCenter") {
            return .scoreCenter(date: date == "today" ? nil : date, liveDemo: false)
        }
        guard let season = defaults.string(forKey: "season") else { return nil }
        return .standings(DemoCompetition.all.first { $0.season == season }
            ?? DemoCompetition(name: "Saison \(season)", detail: "", season: season, highlight: []))
    }

    /// Thème posé d'emblée (`-theme idalgo|neutral|media|tokens`).
    static var theme: DemoTheme {
        switch UserDefaults.standard.string(forKey: "theme") {
        case "neutral": .neutral
        case "media": .media
        case "tokens": .tokens
        default: .idalgo
        }
    }

    static var colorScheme: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "appearance") {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }
}
