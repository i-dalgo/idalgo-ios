import Foundation

/// Filtre de statut du Score Center (Tous, En cours, Terminés, À venir), appliqué au jour chargé.
public enum IdalgoStatusFilter: String, Sendable, CaseIterable {
    /// Tous les matchs du jour.
    case all
    /// Les matchs en cours.
    case live
    /// Les matchs terminés.
    case finished
    /// Les matchs à venir.
    case scheduled

    /// Le contest passe-t-il le filtre ?
    public func matches(_ contest: Contest) -> Bool {
        switch self {
        case .all: true
        case .live: contest.status == .live
        case .finished: contest.status == .finished
        case .scheduled: contest.status == .scheduled
        }
    }
}

/// Un jour du Score Center prêt à afficher : libellé du jour, blocs filtrés, lignes de match
/// formatées et lues par VoiceOver.
package struct ScoreCenterPresentation: Sendable, Equatable {
    /// État d'un contest, tel que la ligne le montre.
    package enum State: Sendable, Equatable {
        /// À venir, avec son heure (`nil` si inconnue).
        case scheduled(time: String?)
        /// En cours, avec le libellé de la source (« 45e », « Mi-temps »).
        case live(label: String?)
        case finished
        case postponed
        case cancelled
        /// Statut inconnu du SDK : le libellé de la source tel quel.
        case other(label: String)

        package var isLive: Bool {
            if case .live = self { return true }
            return false
        }
    }

    /// Un camp d'un duel.
    package struct Side: Sendable, Equatable {
        package let name: String
        package let image: Logo?
        /// Score formaté, `nil` tant que le match n'a pas commencé.
        package let score: String?
        /// Vainqueur d'un match terminé.
        package let isWinner: Bool
        /// Perdant d'un match terminé.
        package let isLoser: Bool
    }

    package enum Kind: Sendable, Equatable {
        case headToHead(home: Side, away: Side)
        /// Épreuve classée : son nom.
        case ranked(title: String)
    }

    package struct Row: Sendable, Equatable, Identifiable {
        package var id: String { contest.id }
        package let contest: Contest
        package let kind: Kind
        package let state: State
        /// « Paris SG 2, Lyon 1, terminé ».
        package let accessibilityLabel: String
    }

    package struct Block: Sendable, Equatable, Identifiable {
        package let competition: CompetitionRef
        /// Saison et phase : une compétition jouée en plusieurs saisons le même jour (Ligue des
        /// Nations) donne plusieurs blocs.
        package let id: String
        package let title: String
        package let logo: Logo?
        /// « Journée 9 », à défaut le nom de la phase.
        package let subtitle: String?
        package let season: SeasonRef
        /// Le bloc ouvre un classement (pas en phase à élimination).
        package let hasStandings: Bool
        package let rows: [Row]
    }

    package let date: String
    /// « Aujourd'hui », « Hier », « Demain », sinon « dimanche 8 novembre ».
    package let dayLabel: String
    /// Le jour en toutes lettres sous un libellé relatif ; `nil` sinon.
    package let daySubtitle: String?
    package let previousDate: String?
    package let nextDate: String?
    package let filter: IdalgoStatusFilter
    /// Blocs qui gardent au moins un match du filtre.
    package let blocks: [Block]
    /// Matchs du jour par filtre, pour les puces.
    package let counts: [IdalgoStatusFilter: Int]
    /// Message d'un jour sans match pour le filtre.
    package let emptyMessage: String
    package let hasMoreContests: Bool

    package init(_ scoreCenter: ScoreCenter, filter: IdalgoStatusFilter, now: Date) {
        let timeZone = TimeZone(identifier: scoreCenter.timeZone) ?? .current
        let relative = ScoreCenterFormat.relativeDayLabel(scoreCenter.date, now: now, timeZone: timeZone)
        let longDay = ScoreCenterFormat.longDay(scoreCenter.date)
        date = scoreCenter.date
        dayLabel = relative ?? longDay ?? scoreCenter.date
        daySubtitle = relative == nil ? nil : longDay
        previousDate = scoreCenter.previousDate
        nextDate = scoreCenter.nextDate
        self.filter = filter
        let shown = scoreCenter.allContests.filter(Self.isShown)
        counts = Dictionary(uniqueKeysWithValues: IdalgoStatusFilter.allCases.map { filter in
            (filter, shown.filter(filter.matches).count)
        })
        blocks = scoreCenter.competitions.compactMap { Self.block($0, filter: filter, timeZone: timeZone) }
        emptyMessage = IdalgoStrings.filter(filter).empty
        hasMoreContests = scoreCenter.hasMoreContests
    }

    /// Une forme de contest inconnue n'est pas affichée.
    private static func isShown(_ contest: Contest) -> Bool {
        if case .unsupported = contest { return false }
        return true
    }

    /// Un bloc prêt à afficher : les matchs du filtre ; `nil` s'il n'en garde aucun.
    package static func block(_ block: ScoreCenterCompetition, filter: IdalgoStatusFilter, timeZone: TimeZone) -> Block? {
        let rows = block.contests.filter { isShown($0) && filter.matches($0) }.compactMap { row($0, timeZone: timeZone) }
        guard !rows.isEmpty else { return nil }
        return Block(
            competition: block.competition,
            id: [block.season.id, block.phase?.id ?? ""].joined(separator: "/"),
            title: block.competition.name ?? block.season.name ?? "—",
            logo: block.competition.logo,
            subtitle: block.day.map { IdalgoStrings.matchday($0.number) } ?? block.phase?.name,
            season: block.season,
            hasStandings: block.phase?.format != .knockout,
            rows: rows
        )
    }

    /// Une ligne de match prête à afficher ; `nil` pour une forme de contest inconnue.
    package static func row(_ contest: Contest, timeZone: TimeZone) -> Row? {
        switch contest {
        case let .headToHead(duel):
            let state = state(duel.status, label: duel.statusLabel, startsAt: duel.startsAt, timeZone: timeZone)
            let (home, away) = sides(duel, state: state)
            return Row(
                contest: contest,
                kind: .headToHead(home: home, away: away),
                state: state,
                accessibilityLabel: accessibilityLabel(home: home, away: away, state: state, startsAt: duel.startsAt, timeZone: timeZone)
            )
        case let .ranked(event):
            let state = state(event.status, label: event.statusLabel, startsAt: event.startsAt, timeZone: timeZone)
            let title = event.name ?? event.competition.name ?? "—"
            return Row(
                contest: contest,
                kind: .ranked(title: title),
                state: state,
                accessibilityLabel: [title, spoken(state, startsAt: event.startsAt, timeZone: timeZone)].compactMap { $0 }.joined(separator: ", ")
            )
        case .unsupported:
            return nil
        }
    }

    static func state(_ status: ContestStatus, label: String?, startsAt: Date?, timeZone: TimeZone) -> State {
        switch status {
        case .scheduled: .scheduled(time: startsAt.map { ScoreCenterFormat.time($0, timeZone: timeZone) })
        case .live: .live(label: label)
        case .finished: .finished
        case .postponed: .postponed
        case .cancelled: .cancelled
        default: .other(label: label ?? status.rawValue)
        }
    }

    private static func sides(_ duel: HeadToHeadContest, state: State) -> (Side, Side) {
        let scored = (state == .finished || state.isLive) && duel.home.score != nil && duel.away.score != nil
        let homeScore = scored ? duel.home.score : nil
        let awayScore = scored ? duel.away.score : nil
        let decided = state == .finished && homeScore != nil && homeScore != awayScore
        let homeWins = decided && (homeScore ?? 0) > (awayScore ?? 0)
        let awayWins = decided && !homeWins
        func side(_ side: ContestSide, score: Double?, wins: Bool, loses: Bool) -> Side {
            Side(
                name: side.competitor.name ?? "—",
                image: side.competitor.image,
                score: score.map(StandingsFormat.number),
                isWinner: wins,
                isLoser: loses
            )
        }
        return (
            side(duel.home, score: homeScore, wins: homeWins, loses: awayWins),
            side(duel.away, score: awayScore, wins: awayWins, loses: homeWins)
        )
    }

    private static func accessibilityLabel(home: Side, away: Side, state: State, startsAt: Date?, timeZone: TimeZone) -> String {
        let teams = if let homeScore = home.score, let awayScore = away.score {
            IdalgoStrings.contestScore(home: home.name, homeScore: homeScore, away: away.name, awayScore: awayScore)
        } else {
            IdalgoStrings.versus(home.name, away.name)
        }
        return [teams, spoken(state, startsAt: startsAt, timeZone: timeZone)].compactMap { $0 }.joined(separator: ", ")
    }

    private static func spoken(_ state: State, startsAt: Date?, timeZone: TimeZone) -> String? {
        switch state {
        case .scheduled: startsAt.map { ScoreCenterFormat.spokenTime($0, timeZone: timeZone) }
        case let .live(label): [IdalgoStrings.spokenLive, label].compactMap { $0 }.joined(separator: ", ")
        case .finished: IdalgoStrings.spokenFinished
        case .postponed: IdalgoStrings.spokenPostponed
        case .cancelled: IdalgoStrings.spokenCancelled
        case let .other(label): label
        }
    }
}
