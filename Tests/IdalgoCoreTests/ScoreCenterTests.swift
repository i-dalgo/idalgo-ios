import Foundation
import Testing
@testable import IdalgoCore

@Suite("Score Center : décodage, direct reporté, présentation")
struct ScoreCenterTests {
    static let paris = TimeZone(identifier: "Europe/Paris")!

    static func instant(_ value: String) -> Date { IdalgoDate.parse(value)! }

    // MARK: Décodage

    @Test("jour terminé : cinq blocs, phases, journées, duels")
    func finished() throws {
        let day = try Fixtures.scoreCenter("score-center-finished")
        #expect(day.date == "2026-11-08")
        #expect(day.timeZone == "Europe/Paris")
        #expect(day.previousDate == "2026-11-07")
        #expect(day.nextDate == "2026-11-12")
        #expect(day.competitions.map { $0.competition.name } == ["Ligue 1", "Premier League", "Liga", "Serie A", "Bundesliga"])
        #expect(day.competitions[0].phase?.format == .league)
        #expect(day.competitions[0].day?.number == 10)
        guard case let .headToHead(first) = day.competitions[0].contests[0] else {
            Issue.record("duel attendu")
            return
        }
        #expect(first.status == .finished)
        #expect(first.startsAt == Self.instant("2026-11-08T15:00:00.000Z"))
        #expect(first.home.competitor.name == "Rennes")
        #expect(first.home.score == 1)
        #expect(first.away.score == 2)
        #expect(first.home.competitor.image?.small.width == 32)
        #expect(day.allContests.allSatisfy { $0.status == .finished })
    }

    @Test("jour à venir : deux blocs de la même compétition, saisons différentes")
    func scheduled() throws {
        let day = try Fixtures.scoreCenter("score-center-scheduled")
        #expect(day.competitions.count == 2)
        #expect(day.competitions.map(\.season.id) == ["369003", "369103"])
        #expect(day.competitions.allSatisfy { $0.phase?.format == .groups })
        #expect(day.allContests.allSatisfy { $0.status == .scheduled })
    }

    @Test("jour sans match : blocs vides, jours voisins donnés")
    func empty() throws {
        let day = try Fixtures.scoreCenter("score-center-empty")
        #expect(day.competitions.isEmpty)
        #expect(day.previousDate == "2026-11-08")
        #expect(day.nextDate == "2026-11-20")
        #expect(!day.hasMoreContests)
    }

    @Test("routes live : contests et pollAfter")
    func live() throws {
        let scheduled = try Fixtures.scoreCenterLive("score-center-live-scheduled")
        #expect(scheduled.meta.pollAfter == 60)
        #expect(scheduled.data.contests.count == 8)
        let inplay = try Fixtures.scoreCenterLive("score-center-live-inplay")
        #expect(inplay.meta.pollAfter == 15)
        guard case let .headToHead(first) = inplay.data.contests[0] else {
            Issue.record("duel attendu")
            return
        }
        #expect(first.status == .live)
        #expect(first.statusLabel == "45e")
        #expect(first.home.score == 1)
    }

    @Test("statut, forme de contest et de concurrent inconnus ne font pas échouer la réponse")
    func unknownValues() throws {
        var object = try JSONSerialization.jsonObject(with: Fixtures.data("score-center-scheduled")) as! [String: Any]
        var data = object["data"] as! [String: Any]
        var blocks = data["competitions"] as! [[String: Any]]
        var contests = blocks[0]["contests"] as! [[String: Any]]
        contests[0]["status"] = "suspended"
        contests[0]["statusLabel"] = "Interrompu"
        var away = contests[0]["away"] as! [String: Any]
        away["competitor"] = ["type": "robot", "id": "1"]
        contests[0]["away"] = away
        contests[1] = ["type": "relay", "id": "77"]
        blocks[0]["contests"] = contests
        data["competitions"] = blocks
        object["data"] = data
        let json = try JSONSerialization.data(withJSONObject: object)
        let day = try JSONDecoder().decode(Envelope<ScoreCenter>.self, from: json).data
        #expect(day.competitions[0].contests[0].status == ContestStatus(rawValue: "suspended"))
        #expect(day.competitions[0].contests[0].status?.isKnown == false)
        #expect(day.competitions[0].contests[1] == .unsupported(type: "relay", id: "77"))
        let presentation = ScoreCenterPresentation(day, filter: .all, now: Self.instant("2026-11-17T12:00:00Z"))
        let row = try #require(presentation.blocks.first?.rows.first)
        #expect(row.state == .other(label: "Interrompu"))
        #expect(presentation.blocks[0].rows.count == 1)
        #expect(presentation.counts[.all] == 7)
    }

    // MARK: Direct

    @Test("le direct se reporte sur les duels du jour, par id")
    func mergeLive() throws {
        let day = try Fixtures.scoreCenter("score-center-scheduled")
        let live = try Fixtures.scoreCenterLive("score-center-live-inplay").data
        let merged = day.applying(live)
        let byId = Dictionary(uniqueKeysWithValues: merged.allContests.map { ($0.id, $0) })
        guard case let .headToHead(denmark) = byId["54436503"], case let .headToHead(ukraine) = byId["54438903"] else {
            Issue.record("duels attendus")
            return
        }
        #expect(denmark.status == .live)
        #expect(denmark.statusLabel == "45e")
        #expect(denmark.home.score == 1)
        #expect(denmark.away.score == 0)
        #expect(denmark.home.competitor.name == "Danemark")
        #expect(ukraine.status == .finished)
        #expect(ukraine.home.score == 3)
        #expect(merged.competitions.map(\.contests.count) == day.competitions.map(\.contests.count))
        #expect(day.applying(ScoreCenterLive(contests: [])) == day)
    }

    // MARK: Présentation

    @Test("lignes : heure à venir, score et vainqueur, direct, lecture VoiceOver")
    func rows() throws {
        let finished = ScoreCenterPresentation(try Fixtures.scoreCenter("score-center-finished"), filter: .all, now: Self.instant("2026-11-17T12:00:00Z"))
        let rennes = try #require(finished.blocks.first?.rows.first)
        guard case let .headToHead(home, away) = rennes.kind else {
            Issue.record("duel attendu")
            return
        }
        #expect(rennes.state == .finished)
        #expect(home.score == "1" && away.score == "2")
        #expect(away.isWinner && home.isLoser)
        #expect(rennes.accessibilityLabel == "Rennes 1, Lille 2, terminé")

        let scheduledDay = try Fixtures.scoreCenter("score-center-scheduled")
        let scheduled = ScoreCenterPresentation(scheduledDay, filter: .all, now: Self.instant("2026-11-17T12:00:00Z"))
        let denmark = try #require(scheduled.blocks.first?.rows.first)
        #expect(denmark.state == .scheduled(time: "21:45"))
        #expect(denmark.accessibilityLabel == "Danemark contre Norvège, à 21 h 45")

        let live = ScoreCenterPresentation(
            scheduledDay.applying(try Fixtures.scoreCenterLive("score-center-live-inplay").data),
            filter: .all,
            now: Self.instant("2026-11-17T21:30:00Z")
        )
        let inPlay = try #require(live.blocks.first?.rows.first)
        #expect(inPlay.state == .live(label: "45e"))
        #expect(inPlay.accessibilityLabel == "Danemark 1, Norvège 0, en cours, 45e")
        guard case let .headToHead(liveHome, _) = inPlay.kind else { return }
        #expect(!liveHome.isWinner)
    }

    @Test("filtre de statut : compte par filtre, blocs vidés retirés, message du jour vide")
    func filterCounts() throws {
        let day = try Fixtures.scoreCenter("score-center-scheduled")
            .applying(try Fixtures.scoreCenterLive("score-center-live-inplay").data)
        let now = Self.instant("2026-11-17T21:30:00Z")
        let all = ScoreCenterPresentation(day, filter: .all, now: now)
        #expect(all.counts == [.all: 8, .live: 2, .finished: 1, .scheduled: 5])
        let live = ScoreCenterPresentation(day, filter: .live, now: now)
        #expect(live.blocks.count == 1)
        #expect(live.blocks[0].rows.map(\.id) == ["54436503", "54436603"])
        let finished = ScoreCenterPresentation(day, filter: .finished, now: now)
        #expect(finished.blocks.map(\.id) == ["369103/600403"])
        let none = ScoreCenterPresentation(try Fixtures.scoreCenter("score-center-finished"), filter: .live, now: now)
        #expect(none.blocks.isEmpty)
        #expect(none.emptyMessage == "Aucun match en cours ce jour-là.")
    }

    @Test("bloc : titre, journée, saison, classement sauf à élimination")
    func blocks() throws {
        let presentation = ScoreCenterPresentation(try Fixtures.scoreCenter("score-center-finished"), filter: .all, now: Self.instant("2026-11-17T12:00:00Z"))
        let ligue1 = try #require(presentation.blocks.first)
        #expect(ligue1.title == "Ligue 1")
        #expect(ligue1.subtitle == "Journée 10")
        #expect(ligue1.season.id == "374703")
        #expect(ligue1.hasStandings)
    }

    // MARK: Jours

    @Test("libellé du jour dans le fuseau : aujourd'hui, hier, demain, sinon en toutes lettres")
    func dayLabels() {
        // 23 h 30 à Paris le 17, déjà le 18 à Tokyo.
        let now = Self.instant("2026-11-17T22:30:00Z")
        #expect(ScoreCenterFormat.dayLabel("2026-11-17", now: now, timeZone: Self.paris) == "Aujourd'hui")
        #expect(ScoreCenterFormat.dayLabel("2026-11-16", now: now, timeZone: Self.paris) == "Hier")
        #expect(ScoreCenterFormat.dayLabel("2026-11-18", now: now, timeZone: Self.paris) == "Demain")
        #expect(ScoreCenterFormat.dayLabel("2026-11-18", now: now, timeZone: TimeZone(identifier: "Asia/Tokyo")!) == "Aujourd'hui")
        #expect(ScoreCenterFormat.dayLabel("2026-11-08", now: now, timeZone: Self.paris) == "dimanche 8 novembre")
        #expect(ScoreCenterFormat.longDay("2027-02-01") == "lundi 1er février")
        #expect(ScoreCenterFormat.time(Self.instant("2026-11-17T20:45:00.000Z"), timeZone: Self.paris) == "21:45")
    }

    @Test("en-tête du jour : date en toutes lettres sous un libellé relatif")
    func daySubtitle() throws {
        let day = try Fixtures.scoreCenter("score-center-scheduled")
        let today = ScoreCenterPresentation(day, filter: .all, now: Self.instant("2026-11-17T12:00:00Z"))
        #expect(today.dayLabel == "Aujourd'hui")
        #expect(today.daySubtitle == "mardi 17 novembre")
        let later = ScoreCenterPresentation(day, filter: .all, now: Self.instant("2026-12-01T12:00:00Z"))
        #expect(later.dayLabel == "mardi 17 novembre")
        #expect(later.daySubtitle == nil)
    }
}
