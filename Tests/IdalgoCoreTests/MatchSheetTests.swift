import Foundation
import Testing
@testable import IdalgoCore

/// Cas repris de `apps/ui-kit/src/utils/match-sheet.test.ts`, plus les fixtures de la feuille.
@Suite("Feuille de match")
struct MatchSheetTests {
    static let paris = TimeZone(identifier: "Europe/Paris")!
    static let gyokeres = PersonRef(id: "1", name: "Viktor Gyökeres", photo: nil)

    static func action(
        _ type: String, _ family: String, minute: Double, side: Side? = .home,
        period: String = "1ère mi-temps", person: PersonRef? = gyokeres, related: PersonRef? = nil, id: String? = nil
    ) -> ContestAction {
        ContestAction(
            id: id ?? "\(type)-\(Int(minute))", type: ActionType(rawValue: type), family: ActionFamily(rawValue: family),
            minute: minute, period: period, side: side, person: person, relatedPerson: related
        )
    }

    static func goal(_ minute: Double, _ side: Side, period: String = "1ère mi-temps") -> ContestAction {
        action("goal", "goal", minute: minute, side: side, period: period, id: "g\(Int(minute))")
    }

    // MARK: Décodage

    @Test("match terminé : en-tête, actions, compositions, avant-match")
    func finished() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-finished")
        #expect(sheet.contest.id == "54732603")
        #expect(sheet.contest.status == .finished)
        #expect(sheet.contest.home.score == 2 && sheet.contest.away.score == 1)
        #expect(sheet.contest.venue?.capacity == 60704)
        #expect(sheet.contest.officials.first?.country?.code == "ENG")
        #expect(sheet.contest.periods.count == 2)
        #expect(sheet.actions.count == 18)
        #expect(sheet.lineups.map(\.formation) == ["4-2-3-1", "3-4-3 Classique"])
        #expect(sheet.lineups.map(\.starters.count) == [11, 11])
        #expect(sheet.lineups.map(\.substitutes.count) == [9, 9])
        #expect(sheet.lineups[0].coach?.name == "Mikel Arteta")
        #expect(sheet.standings.overall != nil && sheet.standings.home != nil && sheet.standings.away != nil)
        #expect(sheet.form.home.count == 5)
        #expect(sheet.keyPlayers?.home.scorer?.person.name == "Martin Odegaard")
        #expect(sheet.headToHead?.contestCount == 25)
        #expect(sheet.headToHead?.mostFrequentScore == [1, 0])
    }

    @Test("match à venir : sans actions ni compositions, sans joueurs clés")
    func scheduled() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-scheduled")
        #expect(sheet.contest.status == .scheduled)
        #expect(sheet.actions.isEmpty)
        #expect(sheet.lineups.allSatisfy { $0.starters.isEmpty && $0.substitutes.isEmpty })
        #expect(sheet.keyPlayers == nil)
        #expect(sheet.headToHead != nil)
        #expect(MatchSheetTab.automatic(for: sheet.contest.status) == .preview)
    }

    @Test("routes live : contest, actions, compositions, pollAfter")
    func live() throws {
        let inplay = try Fixtures.matchSheetLive("match-sheet-live-inplay")
        #expect(inplay.meta.pollAfter == 15)
        #expect(inplay.data.contest.status == .live)
        #expect(inplay.data.contest.statusLabel == "67e")
        #expect(inplay.data.actions.count == 8)
        let scheduled = try Fixtures.matchSheetLive("match-sheet-live-scheduled")
        #expect(scheduled.meta.pollAfter == 60)
        #expect(scheduled.data.actions.isEmpty)
    }

    @Test("le direct remplace en-tête, actions et compositions, garde l'avant-match")
    func applyLive() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-finished")
        let live = try Fixtures.matchSheetLive("match-sheet-live-inplay").data
        let merged = sheet.applying(live)
        #expect(merged.contest.status == .live)
        #expect(merged.contest.home.score == 1 && merged.contest.away.score == 1)
        #expect(merged.actions.count == 8)
        #expect(merged.standings == sheet.standings)
        #expect(merged.headToHead == sheet.headToHead)
        let header = MatchSheetHeader(merged, timeZone: Self.paris)
        #expect(header.state == .live(label: "67e"))
        #expect(header.home.score == "1" && header.away.score == "1")
        #expect(header.halfTime == "mi-temps 0 – 0")
    }

    @Test("le direct d'un match commence 90 min avant le coup d'envoi")
    func liveSchedule() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-scheduled")
        let kickoff = try #require(sheet.contest.startsAt)
        #expect(LiveSchedule.startDelay(status: sheet.contest.status, startsAt: kickoff, now: kickoff.addingTimeInterval(-2 * 3600)) == TimeInterval(30 * 60))
        let finished = try Fixtures.matchSheet("match-sheet-finished")
        #expect(LiveSchedule.startDelay(status: finished.contest.status, startsAt: finished.contest.startsAt, now: Date()) == nil)
    }

    // MARK: Formats

    @Test("nom de famille, minute, décimal, score fréquent, saison courte, milliers")
    func formats() {
        #expect(MatchSheetFormat.lastName("Riccardo Calafiori") == "Calafiori")
        #expect(MatchSheetFormat.lastName("Lucas Hernández Pi") == "Hernández Pi")
        #expect(MatchSheetFormat.lastName("Vitinha") == "Vitinha")
        #expect(MatchSheetFormat.lastName(nil) == "—")
        #expect(MatchSheetFormat.minute(45) == "45’")
        #expect(MatchSheetFormat.minute(nil) == "")
        #expect(MatchSheetFormat.decimal(2.1) == "2,1")
        #expect(MatchSheetFormat.decimal(nil) == "—")
        #expect(MatchSheetFormat.frequentScore([1, 0]) == "1-0")
        #expect(MatchSheetFormat.frequentScore(nil) == "—")
        #expect(MatchSheetFormat.shortSeason("Premier League 2025/2026") == "25/26")
        #expect(MatchSheetFormat.shortSeason("Coupe du monde 2026") == "26")
        #expect(MatchSheetFormat.shortSeason("Pro League") == "Pro League")
        #expect(MatchSheetFormat.grouped(60704) == "60\u{202F}704")
        #expect(MatchSheetFormat.grouped(999) == "999")
        #expect(MatchSheetFormat.dateTime(IdalgoDate.parse("2026-10-10T13:30:00.000Z")!, timeZone: Self.paris) == "samedi 10 octobre 2026 à 15:30")
    }

    // MARK: Actions

    @Test("ce que la feuille dessine pour chaque famille et type", arguments: [
        ("goal", "header-goal", ActionKind?.some(.goal)),
        ("own-goal", "own-goal", .some(.ownGoal)),
        ("card", "yellow-card", .some(.yellowCard)),
        ("card", "second-yellow-card", .some(.secondYellowCard)),
        ("card", "red-card", .some(.redCard)),
        ("substitution", "injury-substitution", .some(.substitution)),
        ("shootout", "shootout-missed", .some(.shootoutMissed)),
        ("shot", "shot", nil),
        ("var", "var", nil),
        ("drone", "drone-sighting", .some(.other(label: "drone-sighting"))),
    ])
    func kinds(family: String, type: String, kind: ActionKind?) {
        #expect(MatchActions.kind(of: Self.action(type, family, minute: 1)) == kind)
    }

    @Test("le score suit les buts, une coupure à chaque changement de période")
    func timeline() {
        let rows = MatchActions.timeline([
            Self.goal(45, .home),
            Self.goal(48, .away, period: "2ème mi-temps"),
            Self.action("yellow-card", "card", minute: 50, period: "2ème mi-temps"),
            Self.action("shot", "shot", minute: 55, period: "2ème mi-temps"),
        ], finished: false)
        #expect(rows == [
            .action(Self.goal(45, .home), kind: .goal, score: MatchScore(home: 1, away: 0)),
            .pause(label: "Mi-temps", score: MatchScore(home: 1, away: 0)),
            .action(Self.goal(48, .away, period: "2ème mi-temps"), kind: .goal, score: MatchScore(home: 1, away: 1)),
            .action(Self.action("yellow-card", "card", minute: 50, period: "2ème mi-temps"), kind: .yellowCard, score: nil),
        ])
    }

    @Test("un but contre son camp compte pour le camp crédité ; un tir au but, non")
    func ownGoalAndShootout() {
        let rows = MatchActions.timeline([
            Self.action("own-goal", "own-goal", minute: 10, side: .away),
            Self.action("shootout-scored", "shootout", minute: 1, side: .home, period: "Tirs au but"),
        ], finished: true)
        #expect(rows.first == .action(Self.action("own-goal", "own-goal", minute: 10, side: .away), kind: .ownGoal, score: MatchScore(home: 0, away: 1)))
        #expect(rows.last == .pause(label: "Fin du match", score: MatchScore(home: 0, away: 1)))
    }

    @Test("fil du match terminé : mi-temps 0 – 0, fin du match 2 – 1")
    func finishedTimeline() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-finished")
        let pauses = MatchActions.timeline(sheet.actions, finished: true).compactMap { row -> String? in
            if case let .pause(label, score) = row { return "\(label) \(score.text)" }
            return nil
        }
        #expect(pauses == ["Mi-temps 0 – 0", "Fin du match 2 – 1"])
    }

    @Test("les buteurs d'un camp, avec penalty et c.s.c.")
    func scorers() {
        let list = MatchActions.scorers([
            Self.goal(45, .home),
            Self.action("penalty-goal", "goal", minute: 67, id: "p"),
            Self.action("own-goal", "own-goal", minute: 70, id: "o"),
            Self.goal(48, .away),
        ], side: .home)
        #expect(list.map(\.label) == ["Gyökeres 45’", "Gyökeres 67’ (pen.)", "Gyökeres 70’ (c.s.c.)"])
        #expect(list.first?.personId == "1")
    }

    @Test("buteurs de l'en-tête du match terminé")
    func headerScorers() throws {
        let header = MatchSheetHeader(try Fixtures.matchSheet("match-sheet-finished"), timeZone: Self.paris)
        #expect(header.home.scorers.map(\.label) == ["Calafiori 62’", "Guimarães Rodriguez Moura 70’"])
        #expect(header.away.scorers.map(\.label) == ["Justin 56’"])
        #expect(header.context == "Premier League • Phase régulière")
        #expect(header.date == "samedi 10 octobre 2026 à 15:30")
        #expect(header.state == .finished)
        #expect(header.home.isWinner && header.away.isLoser)
        #expect(header.home.standing?.hasSuffix("pts") == true)
    }

    @Test("buts, cartons, sortie et entrée de chaque joueur")
    func marks() {
        let calafiori = PersonRef(id: "2", name: "Riccardo Calafiori", photo: nil)
        let hincapie = PersonRef(id: "3", name: "Piero Hincapié", photo: nil)
        let marks = MatchActions.playerMarks([
            Self.goal(45, .home),
            Self.action("yellow-card", "card", minute: 85),
            Self.action("red-card", "card", minute: 88),
            Self.action("substitution", "substitution", minute: 65, person: hincapie, related: calafiori),
        ])
        #expect(marks["1"]?.goals == 1 && marks["1"]?.yellowCards == 1 && marks["1"]?.redCard == true && marks["1"]?.outAt == nil)
        #expect(marks["2"]?.outAt == "65’" && marks["2"]?.inAt == nil)
        #expect(marks["3"]?.inAt == .init(minute: "65’", replaced: "Calafiori"))
    }

    @Test("lecture VoiceOver d'une action : minute, action, auteur, équipe, score")
    func actionLabel() {
        let saka = PersonRef(id: "7", name: "Bukayo Saka", photo: nil)
        let goal = Self.action("goal", "goal", minute: 67, person: saka)
        #expect(MatchActions.accessibilityLabel(goal, kind: .goal, score: MatchScore(home: 1, away: 1), team: "Arsenal")
            == "67e, but de Bukayo Saka, Arsenal, 1 – 1")
        let sub = Self.action("substitution", "substitution", minute: 63, person: saka, related: Self.gyokeres)
        #expect(MatchActions.accessibilityLabel(sub, kind: .substitution, score: nil, team: "Arsenal")
            == "63e, remplacement, entrée de Bukayo Saka, sortie de Viktor Gyökeres, Arsenal")
    }

    // MARK: Compositions

    @Test("les titulaires se placent à leurs coordonnées, le gardien en haut ; sans coordonnées, à part")
    func pitch() throws {
        let lineup = try Fixtures.matchSheet("match-sheet-finished").lineups[0]
        let (placed, unplaced) = PitchLayout.place(lineup)
        #expect(placed.count == 11)
        #expect(unplaced.isEmpty)
        let raya = try #require(placed.first { $0.player.shirt == 1 })
        #expect(raya.x == 0.5 && raya.y == 0.1)
        let havertz = try #require(placed.first { $0.player.shirt == 29 })
        #expect(havertz.y == 0.9)
        let substitute = lineup.substitutes[0]
        let mixed = Lineup(competitor: lineup.competitor, formation: nil, starters: [substitute, raya.player], substitutes: [], coach: nil)
        #expect(PitchLayout.place(mixed).placed.map(\.player) == [raya.player])
        #expect(PitchLayout.place(mixed).unplaced == [substitute])
    }

    @Test("lecture VoiceOver d'un joueur du terrain")
    func playerLabel() throws {
        let sheet = try Fixtures.matchSheet("match-sheet-finished")
        let marks = MatchActions.playerMarks(sheet.actions)
        let odegaard = try #require(sheet.lineups[0].starters.first { $0.shirt == 8 })
        #expect(PitchLayout.accessibilityLabel(odegaard, marks: marks[odegaard.person.id])
            == "Numéro 8, Odegaard, capitaine, milieu, carton jaune, remplacé à la 91’")
    }

    // MARK: Avant-match

    @Test("forme : pastilles V / N / D et leur lecture")
    func form() throws {
        let chips = try Fixtures.matchSheet("match-sheet-finished").form.home.map(FormChip.init)
        #expect(chips.count == 5)
        #expect(chips[0].letter == "D")
        #expect(chips[0].accessibilityLabel == "Défaite 0-3 contre Brighton HAFC")
        #expect(chips[1].letter == "V")
    }

    @Test("classement : « 1er • 39 pts », nil sans l'équipe")
    func standingLine() throws {
        let standings = try Fixtures.standings("standings-league-table")
        #expect(MatchSheetFormat.standingLine(standings, teamId: "24803") == "1er • 23 pts")
        #expect(MatchSheetFormat.standingLine(standings, teamId: "999") == nil)
        #expect(MatchSheetFormat.standingLine(nil, teamId: "24803") == nil)
        let nba = try Fixtures.standings("standings-win-percentage")
        #expect(MatchSheetFormat.standingLine(nba, teamId: "1802") == "1er • 100,0 %")
    }

    @Test("joueurs clés : une ligne par statistique, seulement si un camp a un joueur")
    func keyPlayers() throws {
        let lines = KeyPlayerLine.lines(try #require(try Fixtures.matchSheet("match-sheet-finished").keyPlayers))
        #expect(lines.first?.label == "Buteur")
        #expect(lines.first?.home?.name == "Odegaard")
        #expect(lines.first?.home?.detail == "3 buts")
        #expect(lines.first?.away?.name == "Calvert-Lewin")
        #expect(lines.map(\.id) == ["scorer", "assister"])
        let leader = SeasonLeader(position: 1, person: Self.gyokeres, team: nil, value: 14)
        let single = KeyPlayerLine.lines(MatchSheetKeyPlayers(
            home: MatchSheetTeamLeaders(scorer: leader, assister: nil),
            away: MatchSheetTeamLeaders(scorer: nil, assister: nil)
        ))
        #expect(single.map(\.id) == ["scorer"])
        #expect(single[0].home?.detail == "14 buts")
    }

    @Test("confrontations vues du camp à domicile, quel que soit l'ordre")
    func headToHead() throws {
        let summary = try #require(try Fixtures.matchSheet("match-sheet-finished").headToHead)
        let fromHome = try #require(HeadToHeadBalance(summary, homeId: "7703"))
        #expect(fromHome.results.map(\.value) == [18, 3, 4])
        #expect(fromHome.results[0].label == "Victoires Arsenal")
        #expect(fromHome.averageGoals == "3,2")
        #expect(fromHome.frequentScore == "1-0")
        let fromAway = try #require(HeadToHeadBalance(summary, homeId: "8403"))
        #expect(fromAway.results.map(\.value) == [4, 3, 18])
    }

    @Test("infos : compétition, date, arbitres, stade, capacité")
    func info() throws {
        let rows = InfoRow.rows(try Fixtures.matchSheet("match-sheet-finished").contest, timeZone: Self.paris)
        #expect(rows.first?.value == "Premier League 2026/2027")
        #expect(rows.contains { $0.label == "Principal" && $0.value == "Paul Tierney" && $0.flag != nil })
        #expect(rows.contains { $0.id == "capacity" && $0.value == "60\u{202F}704 places" })
        #expect(!rows.contains { $0.id == "audience" })
    }
}
