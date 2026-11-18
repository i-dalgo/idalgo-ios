import Testing
@testable import IdalgoCore

@Suite("Formatage des classements")
struct FormatTests {
    @Test("pourcentage de victoires : trois décimales, sans zéro initial", arguments: [
        (0.75, ".750"), (1.0, "1.000"), (0.0, ".000"), (0.6667, ".667"),
    ])
    func winPercentage(value: Double, expected: String) {
        #expect(StandingsFormat.winPercentage(value) == expected)
    }

    @Test("retard : tiret à 0, une décimale à la française", arguments: [
        (0.0, "—"), (0.5, "0,5"), (3.0, "3"), (12.5, "12,5"),
    ])
    func gamesBehind(value: Double, expected: String) {
        #expect(StandingsFormat.gamesBehind(value) == expected)
    }

    @Test("différence signée, avec le signe moins typographique", arguments: [
        (12, "+12"), (0, "0"), (-3, "\u{2212}3"),
    ])
    func difference(value: Int, expected: String) {
        #expect(StandingsFormat.difference(value) == expected)
    }

    @Test("évolution : montée, descente, rien à 0 ou inconnue")
    func evolution() {
        #expect(StandingsFormat.evolution(2) == .up(2))
        #expect(StandingsFormat.evolution(-1) == .down(1))
        #expect(StandingsFormat.evolution(0) == nil)
        #expect(StandingsFormat.evolution(nil) == nil)
        #expect(StandingEvolution.up(2).accessibilityLabel == "gagne 2 places")
        #expect(StandingEvolution.down(1).accessibilityLabel == "perd 1 place")
    }

    @Test("ordinal et pluriel à la française")
    func ordinalAndPlural() {
        #expect(IdalgoStrings.ordinal(1) == "1er")
        #expect(IdalgoStrings.ordinal(2) == "2e")
        #expect(IdalgoStrings.plural(0, "point") == "0 point")
        #expect(IdalgoStrings.plural(1, "victoire") == "1 victoire")
        #expect(IdalgoStrings.plural(23, "point") == "23 points")
    }

    @Test("date de calendrier en toutes lettres")
    func calendarDate() {
        #expect(StandingsFormat.calendarDate("2026-11-07") == "7 novembre 2026")
        #expect(StandingsFormat.calendarDate("2027-08-01") == "1er août 2027")
        #expect(StandingsFormat.calendarDate("demain") == nil)
    }

    @Test("nombres : entiers tels quels, sinon une décimale")
    func number() {
        #expect(StandingsFormat.number(23) == "23")
        #expect(StandingsFormat.number(2.5) == "2,5")
    }
}
