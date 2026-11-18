import Foundation
import Testing
@testable import IdalgoCore

@Suite("Décodage des réponses enregistrées")
struct DecodingTests {
    @Test("classement aux points (Ligue 1)")
    func leagueTable() throws {
        guard case let .leagueTable(table) = try Fixtures.standings("standings-league-table") else {
            Issue.record("league-table attendu")
            return
        }
        #expect(table.sport?.code == .football)
        #expect(table.competition.name == "Ligue 1")
        #expect(table.competition.logo?.small.width == 32)
        #expect(table.season == SeasonRef(id: "374703", name: "Ligue 1 2026/2027"))
        #expect(table.split == .overall)
        #expect(table.columns == [.points, .played, .won, .drawn, .lost, .scored, .conceded, .difference])
        #expect(table.groups.count == 1)
        let group = try #require(table.groups.first)
        #expect(group.name == nil)
        #expect(group.day.date == "2026-11-07")
        #expect(group.rows.count == 18)
        let first = try #require(group.rows.first)
        #expect(first.position == 1)
        #expect(first.evolution == 0)
        #expect(first.competitor.name == "Paris SG")
        #expect(first.competitor.logo?.small.url.absoluteString.hasSuffix("32x32/logo_248.png") == true)
        #expect(first.stats.points == 23)
        #expect(first.stats.difference == 12)
    }

    @Test("classement au pourcentage de victoires (NBA)")
    func winPercentage() throws {
        guard case let .winPercentage(table) = try Fixtures.standings("standings-win-percentage") else {
            Issue.record("win-percentage attendu")
            return
        }
        #expect(table.sport?.code == .basketball)
        #expect(table.competition.logo == nil)
        #expect(table.columns == [.won, .lost, .winPct, .gamesBehind])
        let rows = try #require(table.groups.first?.rows)
        #expect(rows.count == 30)
        #expect(rows[0].competitor.logo == nil)
        #expect(rows[0].stats.winPct == 1)
        #expect(rows[5].stats.gamesBehind == 0.5)
    }

    @Test("plusieurs poules (Ligue des Nations)")
    func groups() throws {
        guard case let .leagueTable(table) = try Fixtures.standings("standings-groups") else {
            Issue.record("league-table attendu")
            return
        }
        #expect(table.groups.count == 14)
        #expect(table.groups.map(\.name).allSatisfy { $0?.hasPrefix("Groupe ") == true })
        #expect(table.groups[0].rows.map(\.competitor.name) == ["France", "Belgique", "Italie", "Turquie"])
        #expect(table.groups[3].rows.count == 3)
    }

    @Test("classement à domicile")
    func homeSplit() throws {
        guard case let .leagueTable(table) = try Fixtures.standings("standings-home") else {
            Issue.record("league-table attendu")
            return
        }
        #expect(table.split == .home)
        #expect(table.groups[0].rows[0].competitor.name == "Lyon")
    }

    @Test("erreur 404 de l'API")
    func notFound() throws {
        let error = Problem.error(from: try Fixtures.data("error-not-found"), status: 404, contentType: "application/problem+json")
        #expect(error == .api(status: 404, code: "season-not-found", detail: "Saison 999999999 inconnue"))
    }

    @Test("une forme de classement inconnue ne fait pas échouer la réponse")
    func unknownKind() throws {
        let json = #"{"data":{"kind":"medal-table","groups":[]},"meta":{},"links":{}}"#
        let standings = try JSONDecoder().decode(Envelope<Standings>.self, from: Data(json.utf8)).data
        #expect(standings == .unsupported(kind: "medal-table"))
    }

    @Test("une colonne inconnue est ignorée, un sport inconnu gardé tel quel")
    func unknownColumnAndSport() throws {
        var object = try JSONSerialization.jsonObject(with: Fixtures.data("standings-league-table")) as! [String: Any]
        var data = object["data"] as! [String: Any]
        data["columns"] = ["points", "bonus", "played"]
        data["sport"] = ["id": "9", "code": "padel", "name": "Padel"]
        object["data"] = data
        let json = try JSONSerialization.data(withJSONObject: object)
        guard case let .leagueTable(table) = try JSONDecoder().decode(Envelope<Standings>.self, from: json).data else {
            Issue.record("league-table attendu")
            return
        }
        #expect(table.columns == [.points, .played])
        #expect(table.sport?.code == SportCode(rawValue: "padel"))
    }
}
