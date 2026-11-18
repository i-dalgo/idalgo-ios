import Foundation

/// Rubriques de la feuille de match (`IdalgoMatchSheetView(initialTab:)`).
public enum MatchSheetTab: String, Sendable, CaseIterable {
    case info, actions, lineups, preview

    /// Rubrique ouverte d'emblée : les actions d'un match commencé, l'avant-match sinon.
    package static func automatic(for status: ContestStatus) -> MatchSheetTab {
        status == .live || status == .finished ? .actions : .preview
    }
}

/// En-tête de la feuille : contexte, date, équipes, score ou heure, buteurs.
package struct MatchSheetHeader: Sendable, Equatable {
    package struct Team: Sendable, Equatable {
        package let id: String?
        package let name: String
        package let image: Logo?
        /// « 1er • 39 pts ».
        package let standing: String?
        package let scorers: [Scorer]
        package let score: String?
        package let isWinner: Bool
        package let isLoser: Bool
    }

    /// « Premier League • Phase régulière ».
    package let context: String
    package let competitionLogo: Logo?
    /// « samedi 10 octobre 2026 à 15:30 ».
    package let date: String?
    package let state: ScoreCenterPresentation.State
    package let home: Team
    package let away: Team
    /// « mi-temps 0 – 0 ».
    package let halfTime: String?
    /// « Arsenal 2, Leeds United 1, terminé ».
    package let accessibilityLabel: String

    package init(_ sheet: MatchSheet, timeZone: TimeZone) {
        self.init(contest: sheet.contest, actions: sheet.actions, standings: sheet.standings.overall, timeZone: timeZone)
    }

    /// En-tête d'un match seul : sans actions, pas de buteurs ; sans classement, pas de place.
    package init(contest: HeadToHeadContestDetail, actions: [ContestAction], standings: Standings?, timeZone: TimeZone) {
        context = [contest.competition.name, contest.phase?.name].compactMap { $0 }.joined(separator: " • ")
        competitionLogo = contest.competition.logo
        date = contest.startsAt.map { MatchSheetFormat.dateTime($0, timeZone: timeZone) }
        let row = ScoreCenterPresentation.row(.headToHead(contest.summary), timeZone: timeZone)
        state = row?.state ?? .other(label: contest.status.rawValue)
        accessibilityLabel = row?.accessibilityLabel ?? ""
        let sides: (ScoreCenterPresentation.Side?, ScoreCenterPresentation.Side?) = switch row?.kind {
        case let .headToHead(home, away): (home, away)
        default: (nil, nil)
        }
        func team(_ side: ContestSide, _ presented: ScoreCenterPresentation.Side?, _ key: Side) -> Team {
            Team(
                id: side.competitor.id,
                name: side.competitor.name ?? "—",
                image: side.competitor.image,
                standing: side.competitor.id.flatMap { MatchSheetFormat.standingLine(standings, teamId: $0) },
                scorers: MatchActions.scorers(actions, side: key),
                score: presented?.score,
                isWinner: presented?.isWinner ?? false,
                isLoser: presented?.isLoser ?? false
            )
        }
        home = team(contest.home, sides.0, .home)
        away = team(contest.away, sides.1, .away)
        let first = contest.periods.first
        halfTime = if let first, contest.periods.count > 1, let homeHalf = first.home, let awayHalf = first.away {
            IdalgoStrings.halfTimeScore(StandingsFormat.number(homeHalf), StandingsFormat.number(awayHalf))
        } else {
            nil
        }
    }
}

/// Une ligne de la rubrique Infos.
package struct InfoRow: Sendable, Equatable, Identifiable {
    package let id: String
    package let label: String
    package let value: String
    /// Drapeau de la nationalité d'un arbitre.
    package let flag: CountryFlag?

    /// Les lignes de la rubrique Infos : compétition, phase, date, arbitres, stade, affluence.
    package static func rows(_ contest: HeadToHeadContestDetail, timeZone: TimeZone) -> [InfoRow] {
        var rows: [InfoRow] = []
        func add(_ id: String, _ label: String, _ value: String?, flag: CountryFlag? = nil) {
            if let value { rows.append(InfoRow(id: id, label: label, value: value, flag: flag)) }
        }
        add("competition", IdalgoStrings.competition, contest.season.name ?? contest.competition.name)
        add("phase", IdalgoStrings.phase, contest.phase?.name)
        add("date", IdalgoStrings.date, contest.startsAt.map { MatchSheetFormat.dateTime($0, timeZone: timeZone) })
        for official in contest.officials {
            add("official-\(official.person.id)", official.role ?? IdalgoStrings.referee, official.person.name ?? "—", flag: official.country?.flag)
        }
        add("venue", IdalgoStrings.venue, contest.venue?.name)
        add("capacity", IdalgoStrings.capacity, contest.venue?.capacity.map { IdalgoStrings.places(MatchSheetFormat.grouped($0)) })
        add("audience", IdalgoStrings.audience, contest.audience.map { IdalgoStrings.spectators(MatchSheetFormat.grouped($0)) })
        return rows
    }
}

/// Un match de la forme récente, en pastille : V / N / D.
package struct FormChip: Sendable, Equatable, Identifiable {
    package let id: String
    package let result: FormResult
    package let letter: String
    /// « Victoire 2-0 contre Sunderland ».
    package let accessibilityLabel: String

    package init(_ entry: FormEntry) {
        id = entry.contest.id
        result = entry.result
        letter = IdalgoStrings.formLetter(entry.result)
        let score = [entry.score.scored, entry.score.conceded].compactMap { $0.map(StandingsFormat.number) }.joined(separator: "-")
        accessibilityLabel = [
            IdalgoStrings.formResult(entry.result),
            score.isEmpty ? nil : score,
            IdalgoStrings.against(entry.opponent.name ?? "—"),
        ].compactMap { $0 }.joined(separator: " ")
    }
}

/// Un joueur clé, prêt à afficher : « Gyökeres », « 14 buts ».
package struct KeyPlayer: Sendable, Equatable {
    package let personId: String
    package let name: String
    package let photo: Logo?
    package let detail: String
}

/// Un duel de joueurs clés (buteurs, passeurs) entre les deux équipes.
package struct KeyPlayerLine: Sendable, Equatable, Identifiable {
    package let id: String
    package let label: String
    package let home: KeyPlayer?
    package let away: KeyPlayer?

    /// Une ligne par statistique, seulement si un camp a un joueur.
    package static func lines(_ keyPlayers: MatchSheetKeyPlayers) -> [KeyPlayerLine] {
        func player(_ leader: SeasonLeader?, _ singular: String) -> KeyPlayer? {
            leader.map {
                KeyPlayer(
                    personId: $0.person.id,
                    name: MatchSheetFormat.lastName($0.person.name),
                    photo: $0.person.photo,
                    detail: IdalgoStrings.plural($0.value, singular)
                )
            }
        }
        return [
            KeyPlayerLine(id: "scorer", label: "Buteur", home: player(keyPlayers.home.scorer, "but"), away: player(keyPlayers.away.scorer, "but")),
            KeyPlayerLine(id: "assister", label: "Passeur", home: player(keyPlayers.home.assister, "passe"), away: player(keyPlayers.away.assister, "passe")),
        ].filter { $0.home != nil || $0.away != nil }
    }
}

/// Le bilan des confrontations vu du camp à domicile.
package struct HeadToHeadBalance: Sendable, Equatable {
    package struct Segment: Sendable, Equatable, Identifiable {
        package let id: String
        package let label: String
        package let value: Int
    }

    /// Victoires du domicile, nuls, victoires de l'extérieur.
    package let results: [Segment]
    package let averageGoals: String
    package let scoreless: String
    package let frequentScore: String

    /// `nil` sans les deux équipes.
    package init?(_ summary: HeadToHeadSummary, homeId: String?) {
        guard summary.sides.count == 2 else { return nil }
        let home = summary.sides.first { $0.team.id == homeId } ?? summary.sides[0]
        let away = summary.sides.first { $0 != home } ?? summary.sides[1]
        results = [
            Segment(id: "home", label: IdalgoStrings.wins(home.team.name ?? "—"), value: home.wins),
            Segment(id: "draws", label: IdalgoStrings.draws, value: summary.draws),
            Segment(id: "away", label: IdalgoStrings.wins(away.team.name ?? "—"), value: away.wins),
        ]
        averageGoals = MatchSheetFormat.decimal(summary.averageScored)
        scoreless = String(summary.scorelessCount)
        frequentScore = MatchSheetFormat.frequentScore(summary.mostFrequentScore)
    }
}

/// Un titulaire placé sur le terrain, en fractions de la largeur et de la longueur (le gardien en haut).
package struct PlacedPlayer: Sendable, Equatable, Identifiable {
    package var id: String { player.person.id }
    package let player: LineupPlayer
    package let x: Double
    package let y: Double
}

/// Placement d'une composition sur le terrain, comme les widgets web : chaque titulaire à ses
/// coordonnées (`position`, en %), un titulaire sans coordonnées à part, dans une liste.
package enum PitchLayout {
    package static func place(_ lineup: Lineup) -> (placed: [PlacedPlayer], unplaced: [LineupPlayer]) {
        var placed: [PlacedPlayer] = []
        var unplaced: [LineupPlayer] = []
        for player in lineup.starters {
            if let position = player.position {
                placed.append(PlacedPlayer(
                    player: player,
                    x: min(max(position.x, 0), 100) / 100,
                    y: min(max(position.y, 0), 100) / 100
                ))
            } else {
                unplaced.append(player)
            }
        }
        return (placed, unplaced)
    }

    /// Lecture VoiceOver d'un joueur : « Numéro 8, Odegaard, capitaine, milieu, 1 but, remplacé à la 91’ ».
    package static func accessibilityLabel(_ player: LineupPlayer, marks: PlayerMarks?) -> String {
        var parts = [MatchSheetFormat.lastName(player.person.name)]
        if let shirt = player.shirt { parts.insert("Numéro \(shirt)", at: 0) }
        if player.captain { parts.append(IdalgoStrings.captain) }
        if let label = player.positionLabel { parts.append(label.lowercased()) }
        if let marks {
            if marks.goals > 0 { parts.append(IdalgoStrings.plural(marks.goals, "but")) }
            if marks.ownGoals > 0 { parts.append("but contre son camp") }
            if marks.redCard { parts.append("carton rouge") } else if marks.yellowCards > 0 { parts.append("carton jaune") }
            if let out = marks.outAt { parts.append("remplacé à la \(out)") }
            if let entry = marks.inAt { parts.append("entré à la \(entry.minute) à la place de \(entry.replaced)") }
        }
        return parts.joined(separator: ", ")
    }
}
