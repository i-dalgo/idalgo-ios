import Testing
@testable import IdalgoCore

@Suite("Classement prêt à afficher")
struct PresentationTests {
    @Test("Ligue 1 : colonnes de l'API dans l'ordre, cellules formatées, accessibilité")
    func leagueTable() throws {
        let presentation = try #require(StandingsPresentation(try Fixtures.standings("standings-league-table")))
        #expect(presentation.title == "Ligue 1 2026/2027")
        #expect(presentation.columns.map(\.header) == ["Pts", "J", "V", "N", "D", "+", "\u{2212}", "Diff"])
        #expect(presentation.columns.filter(\.isEmphasized).map(\.id) == ["points"])
        let group = try #require(presentation.groups.first)
        #expect(group.dayLabel == "Après le 7 novembre 2026")
        let first = try #require(group.rows.first)
        #expect(first.cells.map(\.text) == ["23", "10", "7", "2", "1", "22", "10", "+12"])
        #expect(first.cells.last?.tone == .positive)
        #expect(first.accessibilityLabel == "1er, Paris SG, 23 points")
        #expect(first.accessibilityValue.hasPrefix("Points 23, Matchs joués 10, Victoires 7"))
    }

    @Test("NBA : pourcentage et retard formatés, victoires et défaites lues")
    func winPercentage() throws {
        let presentation = try #require(StandingsPresentation(try Fixtures.standings("standings-win-percentage")))
        #expect(presentation.columns.map(\.header) == ["V", "D", "%", "Retard"])
        let rows = try #require(presentation.groups.first?.rows)
        #expect(rows[0].cells.map(\.text) == ["1", "0", "1.000", "—"])
        #expect(rows[5].cells.map(\.text) == ["0", "0", ".000", "0,5"])
        #expect(rows[0].accessibilityLabel == "1er, Oklahoma City Thunder, 1 victoire, 0 défaite")
        #expect(presentation.showsEvolution == false)
        #expect(presentation.columns.first { $0.id == "gamesBehind" }?.characterCount == 6)
    }

    @Test("poules : noms et évolutions")
    func groups() throws {
        let presentation = try #require(StandingsPresentation(try Fixtures.standings("standings-groups")))
        #expect(presentation.groups.count == 14)
        #expect(presentation.groups[0].name == "Groupe 1")
        #expect(presentation.groups[0].id == "837703")
        #expect(presentation.showsEvolution)
        let france = presentation.groups[0].rows[0]
        #expect(france.evolution == .up(1))
        #expect(france.accessibilityLabel == "1er, France, 13 points, gagne 1 place")
    }

    @Test("une forme inconnue n'a pas de présentation")
    func unsupported() {
        #expect(StandingsPresentation(.unsupported(kind: "medal-table")) == nil)
    }
}
