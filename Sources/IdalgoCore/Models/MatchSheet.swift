/// Résultat d'un match de la forme récente, du point de vue de l'équipe.
public enum FormResult: String, Decodable, Sendable, Hashable {
    case win, draw, loss
}

/// Score du point de vue de l'équipe.
public struct FormScore: Decodable, Sendable, Hashable {
    public let scored: Double?
    public let conceded: Double?
}

/// Un match de la forme récente.
public struct FormEntry: Decodable, Sendable, Hashable {
    public let contest: ContestRef
    public let side: Side
    public let opponent: ContestCompetitor
    public let score: FormScore
    public let result: FormResult
}

/// Le bilan d'une des deux équipes dans leurs confrontations.
public struct HeadToHeadSide: Decodable, Sendable, Hashable {
    public let team: TeamCompetitor
    public let wins: Int
    public let scored: Double
}

/// Bilan des confrontations terminées entre deux équipes.
public struct HeadToHeadSummary: Decodable, Sendable, Hashable {
    /// Les deux équipes, dans l'ordre demandé.
    public let sides: [HeadToHeadSide]
    public let contestCount: Int
    public let draws: Int
    /// Buts par match des deux équipes ; `nil` sans match.
    public let averageScored: Double?
    public let scorelessCount: Int
    /// Score le plus fréquent, le plus haut en premier.
    public let mostFrequentScore: [Double]?
    /// Derniers matchs, du plus récent.
    public let last: [Contest]
}

/// Un joueur du classement de la saison et sa valeur (buts, passes).
public struct SeasonLeader: Decodable, Sendable, Hashable {
    public let position: Int
    public let person: PersonRef
    public let team: TeamCompetitor?
    public let value: Int
}

/// Meilleur buteur et meilleur passeur d'une équipe sur la saison.
public struct MatchSheetTeamLeaders: Decodable, Sendable, Hashable {
    public let scorer: SeasonLeader?
    public let assister: SeasonLeader?
}

/// Joueurs clés de chaque équipe.
public struct MatchSheetKeyPlayers: Decodable, Sendable, Hashable {
    public let home: MatchSheetTeamLeaders
    public let away: MatchSheetTeamLeaders
}

/// Classement de la poule du match à sa date : général, à domicile, à l'extérieur.
public struct MatchSheetStandings: Decodable, Sendable, Hashable {
    public let overall: Standings?
    public let home: Standings?
    public let away: Standings?

    /// Les classements servis, par split.
    public var bySplit: [StandingSplit: Standings] {
        var splits: [StandingSplit: Standings] = [:]
        splits[.overall] = overall
        splits[.home] = home
        splits[.away] = away
        return splits
    }
}

/// Derniers matchs terminés de chaque équipe avant ce match, du plus récent.
public struct MatchSheetForm: Decodable, Sendable, Hashable {
    public let home: [FormEntry]
    public let away: [FormEntry]
}

/// Feuille de match (module `match-sheet/v1`) : en-tête, actions, compositions et avant-match.
public struct MatchSheet: Decodable, Sendable, Hashable {
    public internal(set) var contest: HeadToHeadContestDetail
    /// Actions dans l'ordre du match ; vide avant le coup d'envoi.
    public internal(set) var actions: [ContestAction]
    /// Compositions ; titulaires et remplaçants vides tant qu'elles ne sont pas connues.
    public internal(set) var lineups: [Lineup]
    public let standings: MatchSheetStandings
    public let form: MatchSheetForm
    public let keyPlayers: MatchSheetKeyPlayers?
    public let headToHead: HeadToHeadSummary?

    /// La feuille avec une lecture live : en-tête, actions et compositions remplacés, l'avant-match
    /// gardé tel quel.
    public func applying(_ live: MatchSheetLive) -> MatchSheet {
        var copy = self
        copy.contest = live.contest
        copy.actions = live.actions
        copy.lineups = live.lineups
        return copy
    }
}

/// Ce qui bouge sur la feuille pendant le match.
public struct MatchSheetLive: Decodable, Sendable, Hashable {
    public let contest: HeadToHeadContestDetail
    public let actions: [ContestAction]
    public let lineups: [Lineup]
}
