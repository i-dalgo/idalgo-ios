import Foundation
import Testing
@testable import IdalgoCore

/// Lot 2 « adaptable » : compétitions et saison en cours, jetons d'apparence, fenêtre du classement,
/// colonnes compactes, filtre de statut, en-tête d'un match seul.
@Suite("Compétitions")
struct CompetitionTests {
    let clock = TestClock()

    func client(_ transport: StubTransport) -> IdalgoClient {
        IdalgoClient(
            configuration: IdalgoConfiguration(baseURL: URL(string: "https://api.example.test")!),
            transport: transport,
            retryPolicy: .none,
            now: { [clock] in clock.now },
            sleep: { _ in }
        )
    }

    static func page(_ ids: [String], cursor: String?, season: Bool = true) -> StubTransport.Reply {
        let items = ids.map { id in
            """
            {"id":"\(id)","name":"Compétition \(id)","logo":null,
             "sport":{"id":"102","code":"football","name":"Football"},
             "currentSeason":\(season ? "{\"id\":\"s\(id)\",\"name\":\"Saison \(id)\"}" : "null")}
            """
        }
        let meta = cursor.map { "{\"cursor\":\"\($0)\"}" } ?? "{\"cursor\":null}"
        let body = "{\"data\":[\(items.joined(separator: ","))],\"meta\":\(meta),\"links\":{}}"
        return .response(status: 200, body: Data(body.utf8), headers: ["Content-Type": "application/json"])
    }

    @Test("competitions(sport:) suit le curseur jusqu'à la dernière page, 100 par page")
    func pages() async throws {
        let transport = StubTransport([Self.page(["103", "203"], cursor: "c1"), Self.page(["303"], cursor: nil)])
        let competitions = try await client(transport).competitions(sport: "102")
        #expect(competitions.map(\.id) == ["103", "203", "303"])
        #expect(competitions[0].currentSeason?.id == "s103")
        #expect(competitions[0].sport?.code == .football)
        let urls = transport.requests.compactMap { $0.url?.absoluteString }
        #expect(urls == [
            "https://api.example.test/v1/competitions?lang=fr&limit=100&sport=102",
            "https://api.example.test/v1/competitions?cursor=c1&lang=fr&limit=100&sport=102",
        ])
    }

    @Test("competition(id:) lit /v1/competitions?ids= ; absente : 404 not-found")
    func single() async throws {
        let transport = StubTransport([Self.page(["103"], cursor: nil), Self.page([], cursor: nil)])
        let client = client(transport)
        let competition = try await client.competition(id: "103")
        #expect(competition.name == "Compétition 103")
        #expect(transport.requests[0].url?.absoluteString == "https://api.example.test/v1/competitions?ids=103&lang=fr")
        await #expect(throws: IdalgoError.api(status: 404, code: .notFound, detail: IdalgoStrings.competitionNotFound)) {
            try await client.competition(id: "999")
        }
    }

    @Test("la saison en cours n'est lue qu'une fois par client")
    func currentSeasonMemoised() async throws {
        let transport = StubTransport([Self.page(["103"], cursor: nil)])
        let client = client(transport)
        #expect(try await client.currentSeasonID(competition: "103") == "s103")
        #expect(try await client.currentSeasonID(competition: "103") == "s103")
        #expect(transport.requests.count == 1)
    }

    @Test("sans saison en cours : 404 not-found, message en français")
    func noCurrentSeason() async throws {
        let transport = StubTransport([Self.page(["103"], cursor: nil, season: false)])
        await #expect(throws: IdalgoError.api(status: 404, code: .notFound, detail: IdalgoStrings.noCurrentSeason)) {
            try await client(transport).currentSeasonID(competition: "103")
        }
    }
}

@Suite("Jetons d'apparence")
struct AppearanceTokenTests {
    static let base = """
    {"name":"Média","colors":{"primary":"#b3122e","secondary":"#5c4a4f","background":"#fffdf9","text":"#1f1416"},
     "fonts":{"heading":"Georgia, serif","body":"Georgia, serif"}
    """

    static func theme(_ extra: String = "") throws -> IdalgoTheme {
        try IdalgoTheme(json: Data((base + extra + "}").utf8))
    }

    @Test("un ThemeConfig web sans les nouveaux champs reste valide, avec les défauts")
    func legacyJSON() throws {
        let theme = try Self.theme()
        #expect(theme.statusColors == IdalgoTheme.StatusColors())
        #expect(theme.fontScale == 1)
        #expect(theme.density == .regular)
        #expect(theme.background == .theme)
        #expect(theme.mode == .light)
    }

    @Test("statusColors, fontScale, density et background se décodent")
    func tokens() throws {
        let theme = try Self.theme("""
        ,"statusColors":{"live":"#e8590c","win":"#2b8a3e","redCard":"#ff0000"},
         "fontScale":1.2,"density":"compact","background":"transparent"
        """)
        #expect(theme.statusColors.live == "#e8590c")
        #expect(theme.statusColors[.win] == "#2b8a3e")
        #expect(theme.statusColors[.redCard] == "#ff0000")
        #expect(theme.statusColors[.draw] == nil)
        #expect(theme.fontScale == 1.2)
        #expect(theme.density == .compact)
        #expect(theme.background == .transparent)
    }

    @Test("une valeur illisible garde le défaut sans faire échouer le thème")
    func tolerant() throws {
        let theme = try Self.theme(#","fontScale":"grand","density":"serré","background":"rose","statusColors":42"#)
        #expect(theme.fontScale == 1)
        #expect(theme.density == .regular)
        #expect(theme.background == .theme)
        #expect(theme.statusColors == IdalgoTheme.StatusColors())
    }

    @Test("fontScale est borné à 0,5…2")
    func fontScaleBounds() {
        var theme = IdalgoTheme.default
        for (value, expected) in [(0.1, 0.5), (1.3, 1.3), (5.0, 2.0), (Double.nan, 1.0)] {
            theme.fontScale = value
            #expect(theme.effectiveFontScale == expected)
        }
    }
}

@Suite("Fenêtre du classement")
struct StandingsWindowTests {
    let rows: [StandingsPresentation.Row]

    init() throws {
        rows = try #require(StandingsPresentation(Fixtures.standings("standings-league-table"))).groups[0].rows
    }

    func shown(_ items: [StandingsWindow.Item]) -> [String] {
        items.map { item in
            switch item {
            case let .row(row): String(row.position)
            case .gap: "…"
            }
        }
    }

    @Test("sans limit ni around : toutes les lignes")
    func all() {
        #expect(StandingsWindow.items(rows, highlight: [], limit: nil, around: nil).count == rows.count)
        #expect(StandingsWindow.items(rows, highlight: [], limit: 0, around: nil).count == rows.count)
    }

    @Test("limit : les N premières, sans coupure")
    func top() {
        #expect(shown(StandingsWindow.items(rows, highlight: [], limit: 5, around: nil)) == ["1", "2", "3", "4", "5"])
    }

    @Test("around : les lignes autour de l'équipe mise en avant")
    func around() {
        let team = rows[10].id
        #expect(shown(StandingsWindow.items(rows, highlight: [team], limit: nil, around: 1)) == ["10", "11", "12"])
    }

    @Test("limit et around : les deux morceaux, une coupure entre eux")
    func union() {
        let team = rows[10].id
        let items = StandingsWindow.items(rows, highlight: [team], limit: 3, around: 1)
        #expect(shown(items) == ["1", "2", "3", "…", "10", "11", "12"])
        #expect(items[3].id == "gap-\(rows[2].id)")
        // Morceaux contigus : pas de coupure.
        #expect(shown(StandingsWindow.items(rows, highlight: [rows[3].id], limit: 3, around: 1)) == ["1", "2", "3", "4", "5"])
    }

    @Test("around sans équipe mise en avant dans la poule : limit, sinon toutes les lignes")
    func aroundWithoutHighlight() {
        #expect(shown(StandingsWindow.items(rows, highlight: ["absente"], limit: 2, around: 1)) == ["1", "2"])
        #expect(StandingsWindow.items(rows, highlight: [], limit: nil, around: 2).count == rows.count)
    }
}

@Suite("Classement compact")
struct CompactStandingsTests {
    @Test("aux points : J, Diff, Pts dans l'ordre de l'API, cellules alignées")
    func leagueTable() throws {
        let full = try #require(StandingsPresentation(Fixtures.standings("standings-league-table")))
        let compact = full.compacted()
        #expect(compact.columns.map(\.id) == ["points", "played", "difference"])
        let row = compact.groups[0].rows[0]
        #expect(row.cells.count == 3)
        #expect(row.cells[0] == full.groups[0].rows[0].cells[0])
        #expect(row.cells[2] == full.groups[0].rows[0].cells.last)
    }

    @Test("aux victoires : V, D, %")
    func winPercentage() throws {
        let compact = try #require(StandingsPresentation(Fixtures.standings("standings-win-percentage"))).compacted()
        #expect(Set(compact.columns.map(\.id)) == ["won", "lost", "winPct"])
    }
}

@Suite("Filtre de statut et en-tête seul")
struct StatusFilterTests {
    @Test("chaque filtre ne garde que ses matchs ; un bloc sans match du filtre disparaît")
    func filter() throws {
        let day = try Fixtures.scoreCenter("score-center-finished")
        let contests = day.allContests
        #expect(contests.filter(IdalgoStatusFilter.all.matches).count == contests.count)
        #expect(contests.filter(IdalgoStatusFilter.finished.matches).allSatisfy { $0.status == .finished })
        let block = try #require(day.competitions.first)
        #expect(ScoreCenterPresentation.block(block, filter: .live, timeZone: .current) == nil)
        #expect(ScoreCenterPresentation.block(block, filter: .all, timeZone: .current)?.rows.count == block.contests.count)
    }

    @Test("l'en-tête d'un match seul n'a ni buteurs ni place au classement")
    func headerWithoutSheet() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-finished")
        let full = MatchSheetHeader(sheet, timeZone: .current)
        let bare = MatchSheetHeader(contest: sheet.contest, actions: [], standings: nil, timeZone: .current)
        #expect(!full.home.scorers.isEmpty)
        #expect(bare.home.scorers.isEmpty && bare.home.standing == nil)
        #expect(bare.state == full.state && bare.home.score == full.home.score)
    }
}
