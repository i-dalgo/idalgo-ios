import Foundation
import SwiftUI
import Testing
@testable import IdalgoKit

/// Réponses enregistrées (`mobile/fixtures`, ou `Tests/Fixtures` dans le dépôt public du paquet).
enum KitFixtures {
    static func data(_ name: String) throws -> Data {
        let tests = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let mirrored = tests.appendingPathComponent("Fixtures")
        let directory = FileManager.default.fileExists(atPath: mirrored.path)
            ? mirrored
            : tests.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures")
        return try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
    }
}

/// Transport bouchon : une réponse par chemin (`/modules/score-center/v1` …), requêtes gardées.
final class RouteTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private let routes: @Sendable (URL) -> (Int, Data)
    private var seen: [URL] = []

    init(_ routes: @escaping @Sendable (URL) -> (Int, Data)) {
        self.routes = routes
    }

    var requests: [URL] { lock.withLock { seen } }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = request.url!
        lock.withLock { seen.append(url) }
        let (status, body) = routes(url)
        let headers = ["Content-Type": status < 300 ? "application/json" : "application/problem+json", "Cache-Control": "no-store"]
        return (body, HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

/// Attend qu'une condition devienne vraie (lecture du modèle sur le fil principal).
@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@Suite("Routeur")
@MainActor
struct NavigationRouterTests {
    final class Log {
        var events: [String] = []
    }

    func navigator(_ log: Log, _ result: IdalgoNavigationResult) -> IdalgoNavigator {
        IdalgoNavigator { destination in
            log.events.append("host \(destination)")
            return result
        }
    }

    func opener(_ log: Log) -> DestinationOpener {
        DestinationOpener { log.events.append("sdk \($0)") }
    }

    @Test("le raccourci passe avant le routeur et l'écran du SDK")
    func shortcutFirst() {
        let log = Log()
        let outcome = NavigationOutcome.route(
            .contest(id: "1"), shortcut: { log.events.append("shortcut") },
            navigator: navigator(log, .handled), opener: opener(log)
        )
        #expect(outcome == .shortcut)
        #expect(log.events == ["shortcut"])
    }

    @Test(".handled : l'app s'en charge, le SDK n'ouvre rien")
    func handled() {
        let log = Log()
        #expect(NavigationOutcome.route(.contest(id: "1"), shortcut: nil, navigator: navigator(log, .handled), opener: opener(log)) == .host)
        #expect(log.events == ["host contest(id: \"1\")"])
    }

    @Test(".default : le SDK ouvre la feuille de match ou le classement")
    func defaultOpensSDK() {
        let log = Log()
        let standings = IdalgoDestination.standings(season: "374703", highlight: ["24803"])
        #expect(NavigationOutcome.route(standings, shortcut: nil, navigator: navigator(log, .default), opener: opener(log)) == .sdk)
        #expect(log.events.last == "sdk \(standings)")
        #expect(NavigationOutcome.route(.contest(id: "2"), shortcut: nil, navigator: nil, opener: opener(log)) == .sdk)
    }

    @Test("une équipe sans réponse de l'app : rien (le SDK n'a pas d'écran d'équipe)")
    func teamIgnored() {
        let log = Log()
        #expect(NavigationOutcome.route(.team(id: "7"), shortcut: nil, navigator: navigator(log, .default), opener: opener(log)) == .ignored)
        #expect(log.events == ["host team(id: \"7\")"])
        #expect(!NavigationOutcome.isActionable(.team(id: "7"), hasShortcut: false, navigator: nil, opener: opener(log)))
        #expect(NavigationOutcome.isActionable(.team(id: "7"), hasShortcut: false, navigator: navigator(log, .handled), opener: nil))
    }

    @Test("une brique sans raccourci, routeur ni écran du SDK n'est pas touchable")
    func notActionable() {
        #expect(!NavigationOutcome.isActionable(.contest(id: "1"), hasShortcut: false, navigator: nil, opener: nil))
        #expect(NavigationOutcome.isActionable(.contest(id: "1"), hasShortcut: true, navigator: nil, opener: nil))
        #expect(NavigationOutcome.isActionable(.contest(id: "1"), hasShortcut: false, navigator: nil, opener: opener(Log())))
    }

    @Test("le gestionnaire d'équipe : le raccourci tel quel, sinon le routeur, sinon rien")
    func teamHandler() {
        let log = Log()
        let team = TeamCompetitor(id: "9", name: "Lens")
        #expect(NavigationContext(navigator: nil, opener: opener(log)).teamHandler(shortcut: nil) == nil)
        NavigationContext(navigator: navigator(log, .handled), opener: nil).teamHandler(shortcut: nil)?(team)
        NavigationContext(navigator: navigator(log, .handled), opener: nil).teamHandler(shortcut: { log.events.append("tap \($0.id)") })?(team)
        #expect(log.events == ["host team(id: \"9\")", "tap 9"])
    }
}

@Suite("Rubriques de la feuille")
struct MatchSheetTabsTests {
    @Test("rubriques proposées : sans doublon, dans l'ordre ; vides : toutes")
    func visible() {
        #expect(MatchSheetTab.visible([.lineups, .actions, .lineups]) == [.lineups, .actions])
        #expect(MatchSheetTab.visible([]) == MatchSheetTab.allCases)
    }

    @Test("rubrique affichée : la choisie si proposée, sinon la première")
    func shown() {
        #expect(MatchSheetTab.shown(.actions, in: [.lineups, .actions]) == .actions)
        #expect(MatchSheetTab.shown(.preview, in: [.lineups, .actions]) == .lineups)
        #expect(MatchSheetTab.shown(nil, in: [.info]) == .info)
    }
}

@Suite("Thème : jetons résolus")
struct ResolvedTokensTests {
    @Test("couleurs d'état : celles du design system, sinon celles du thème, sinon les natives")
    func statusColors() {
        let standard = ResolvedTheme(.default, mode: .light)
        #expect(standard.live == standard.negative)
        #expect(standard.win == standard.positive)
        #expect(standard.draw == standard.textSecondary)
        #expect(standard.yellowCard == Color(themeColor: "#f5c518"))
        #expect(standard.redCard == Color(themeColor: "#e5322d"))
        var theme = IdalgoTheme.default
        theme.statusColors = IdalgoTheme.StatusColors(live: "#e8590c")
        #expect(ResolvedTheme(theme, mode: .dark).live == Color(themeColor: "#e8590c"))
        let native = theme.with(.live, .purple).with(.primary, .orange)
        #expect(ResolvedTheme(native, mode: .light).live == .purple)
        #expect(ResolvedTheme(native, mode: .dark).primary == .orange)
    }

    @Test("fond transparent : le composant n'en pose pas, les en-têtes gardent le fond du thème")
    func transparent() {
        var theme = IdalgoTheme.neutral
        theme.background = .transparent
        let resolved = ResolvedTheme(theme, mode: .light)
        #expect(resolved.containerBackground == .clear)
        #expect(resolved.background == Color(themeColor: "#ffffff"))
        #expect(ResolvedTheme(.neutral, mode: .light).containerBackground == resolved.background)
    }

    @Test("densité compacte : hauteurs et marges réduites d'un quart")
    func density() {
        var theme = IdalgoTheme.default
        #expect(ResolvedTheme(theme, mode: .light).dense(12) == 12)
        theme.density = .compact
        #expect(ResolvedTheme(theme, mode: .light).dense(12) == 9)
    }

    @Test("fontScale agrandit la police système ; à 1, le style seul")
    func fontScale() {
        let scaled = ThemeFont(stack: "", scale: 1.5)
        #expect(scaled.scaledSize(.body) == 17 * 1.5)
        #expect(ThemeFont(stack: "").scale == 1)
    }

    @Test("un thème aux couleurs natives se distingue de l'autre (cache, mise à jour)")
    func nativeHashable() {
        let base = IdalgoTheme.default
        #expect(base.with(.primary, .red) != base)
        #expect(base.with(.primary, .red) == base.with(.primary, .red))
    }
}

@Suite("Composants de l'app")
@MainActor
struct ComponentsTests {
    struct Custom: IdalgoComponents {
        func emptyState(_ options: IdalgoEmptyStateOptions) -> some View { Text(options.message) }
    }

    @Test("ceux du SDK sont rendus sans effacement ; ceux de l'app sont gardés")
    func box() {
        #expect(ComponentsBox(IdalgoDefaultComponents()).value == nil)
        #expect(ComponentsBox(nil).value == nil)
        #expect(ComponentsBox(Custom()).value is Custom)
    }
}

@Suite("États publics")
@MainActor
struct StateModelTests {
    nonisolated static func client(_ transport: RouteTransport) -> IdalgoClient {
        IdalgoClient(
            configuration: IdalgoConfiguration(baseURL: URL(string: "https://api.example.test")!),
            transport: transport,
            retryPolicy: .none
        )
    }

    nonisolated static func day(_ url: URL) -> (Int, Data) {
        // Un jour terminé : lu, sans direct à suivre.
        let date = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "date" }?.value
        if date == "2000-01-01" { return (404, Data(#"{"status":404,"code":"not-found","detail":"Aucun jour"}"#.utf8)) }
        return (200, (try? KitFixtures.data("score-center-finished")) ?? Data())
    }

    @Test("Score Center : run() lit le jour ; changer la date le relit sans recréer l'état")
    func scoreCenter() async throws {
        let transport = RouteTransport(Self.day)
        let model = IdalgoScoreCenterModel(sport: "102", date: "2026-11-08", status: .finished, client: Self.client(transport))
        let run = Task { await model.run() }
        defer { run.cancel() }
        #expect(await eventually { model.day != nil })
        #expect(model.status == .finished)
        #expect(transport.requests.last?.query?.contains("date=2026-11-08") == true)
        model.showNextDay()
        let next = try #require(model.date)
        #expect(next != "2026-11-08")
        #expect(await eventually { transport.requests.contains { $0.query?.contains("date=\(next)") == true } })
        #expect(await eventually { !model.isRefreshing })
    }

    @Test("Score Center : une erreur, puis retry() relit")
    func scoreCenterRetry() async throws {
        let transport = RouteTransport(Self.day)
        let model = IdalgoScoreCenterModel(sport: "102", date: "2000-01-01", client: Self.client(transport))
        let run = Task { await model.run() }
        defer { run.cancel() }
        #expect(await eventually {
            if case .failed = model.phase { return true }
            return false
        })
        let count = transport.requests.count
        model.retry()
        #expect(await eventually { transport.requests.count > count })
    }

    @Test("sans run(), rien n'est lu ; deux lecteurs ne lisent qu'une fois")
    func runners() async throws {
        let transport = RouteTransport(Self.day)
        let model = IdalgoScoreCenterModel(sport: "102", date: "2026-11-08", client: Self.client(transport))
        model.date = "2026-11-09"
        try await Task.sleep(for: .milliseconds(50))
        #expect(transport.requests.isEmpty)
        let first = Task { await model.run() }
        let second = Task { await model.run() }
        #expect(await eventually { model.day != nil })
        try await Task.sleep(for: .milliseconds(50))
        #expect(transport.requests.count == 1)
        first.cancel()
        second.cancel()
    }

    @Test("Feuille de match : lue, rubrique choisie d'après le statut ; changer de match la relit")
    func matchSheet() async throws {
        let transport = RouteTransport { url in
            let contest = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "contest" }?.value
            let name = contest == "54436503" ? "match-sheet-scheduled" : "match-sheet-finished"
            return (200, (try? KitFixtures.data(name)) ?? Data())
        }
        let model = IdalgoMatchSheetModel(contest: "54732603", client: Self.client(transport))
        let run = Task { await model.run() }
        defer { run.cancel() }
        #expect(await eventually { model.sheet != nil })
        #expect(model.tab == .actions)
        model.contest = "54436503"
        #expect(model.sheet == nil)
        #expect(await eventually { model.sheet?.contest.id == "54436503" })
        #expect(model.tab == .preview)
    }
}
