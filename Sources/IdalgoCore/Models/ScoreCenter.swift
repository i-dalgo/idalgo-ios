/// Format d'une phase. Liste ouverte : une valeur inconnue se décode telle quelle.
public struct PhaseFormat: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let league = PhaseFormat(rawValue: "league")
    public static let groups = PhaseFormat(rawValue: "groups")
    /// Élimination directe : pas de classement à ouvrir.
    public static let knockout = PhaseFormat(rawValue: "knockout")
}

/// Les matchs d'un sport sur un jour, groupés par compétition (module `score-center/v1`).
public struct ScoreCenter: Decodable, Sendable, Hashable {
    /// Jour affiché (`AAAA-MM-JJ`), dans le fuseau `timeZone`.
    public let date: String
    /// Fuseau du jour (nom IANA canonique).
    public let timeZone: String
    /// Jour précédent qui a des matchs ; `nil` s'il n'y en a pas.
    public let previousDate: String?
    /// Jour suivant qui a des matchs ; `nil` s'il n'y en a pas.
    public let nextDate: String?
    /// Blocs par compétition ; vide un jour sans match.
    public internal(set) var competitions: [ScoreCenterCompetition]
    /// Le jour compte plus de matchs que le module n'en renvoie.
    public let hasMoreContests: Bool
}

/// Un bloc du Score Center : les matchs du jour d'une compétition, dans l'ordre de leur heure.
public struct ScoreCenterCompetition: Decodable, Sendable, Hashable {
    public let competition: CompetitionRef
    /// Saison du bloc : celle du classement à ouvrir.
    public let season: SeasonRef
    public let phase: ScoreCenterPhase?
    public let day: ScoreCenterDay?
    public internal(set) var contests: [Contest]
}

/// La phase d'un bloc et son format.
public struct ScoreCenterPhase: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let format: PhaseFormat?
}

/// La journée d'un bloc et son rang dans la phase (« Journée 17 »).
public struct ScoreCenterDay: Decodable, Sendable, Hashable {
    public let id: String
    public let date: String?
    public let number: Int
}

/// Ce qui bouge sur le jour du Score Center pendant qu'il se joue.
public struct ScoreCenterLive: Decodable, Sendable, Hashable {
    public let contests: [LiveContest]
}
