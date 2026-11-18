import Foundation

/// Camp d'un duel.
public enum Side: String, Decodable, Sendable, Hashable {
    case home, away
}

/// Un stade ou un site, avec sa capacité.
public struct Venue: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let capacity: Int?
}

/// Un arbitre ou officiel, son rôle (« Principal »…) et sa nationalité.
public struct Official: Decodable, Sendable, Hashable {
    public let role: String?
    public let person: PersonRef
    public let country: Country?
}

/// Score d'une période pour chaque camp (mi-temps, set…).
public struct PeriodScore: Decodable, Sendable, Hashable {
    public let name: String?
    public let home: Double?
    public let away: Double?
}

/// Un duel en détail : le duel (`summary`), et ses périodes, stade, affluence et arbitres. Les
/// champs du duel se lisent directement (`detail.home`, `detail.status`…).
@dynamicMemberLookup
public struct HeadToHeadContestDetail: Decodable, Sendable, Hashable {
    public let summary: HeadToHeadContest
    public let venue: Venue?
    public let audience: Int?
    public let officials: [Official]
    public let periods: [PeriodScore]

    private enum CodingKeys: String, CodingKey { case venue, audience, officials, periods }

    public init(from decoder: any Decoder) throws {
        summary = try HeadToHeadContest(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        venue = try container.decodeIfPresent(Venue.self, forKey: .venue)
        audience = try container.decodeIfPresent(Int.self, forKey: .audience)
        officials = try container.decode([Official].self, forKey: .officials)
        periods = try container.decode([PeriodScore].self, forKey: .periods)
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<HeadToHeadContest, T>) -> T {
        summary[keyPath: keyPath]
    }
}

/// Nature exacte d'une action (`penalty-goal`, `second-yellow-card`…). Liste ouverte.
public struct ActionType: RawRepresentable, Hashable, Sendable, Codable {
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

    public static let penaltyGoal = ActionType(rawValue: "penalty-goal")
    public static let yellowCard = ActionType(rawValue: "yellow-card")
    public static let secondYellowCard = ActionType(rawValue: "second-yellow-card")
    public static let redCard = ActionType(rawValue: "red-card")
    public static let shootoutScored = ActionType(rawValue: "shootout-scored")
    public static let shootoutMissed = ActionType(rawValue: "shootout-missed")
}

/// Famille d'une action : `goal` réunit les buts marqués, hors contre son camp. Liste ouverte.
public struct ActionFamily: RawRepresentable, Hashable, Sendable, Codable {
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

    public static let goal = ActionFamily(rawValue: "goal")
    public static let ownGoal = ActionFamily(rawValue: "own-goal")
    public static let card = ActionFamily(rawValue: "card")
    public static let substitution = ActionFamily(rawValue: "substitution")
    public static let shootout = ActionFamily(rawValue: "shootout")

    /// Familles que cette version du SDK connaît (montrées ou non sur la feuille).
    static let known: Set<String> = [
        "goal", "own-goal", "disallowed-goal", "shot", "shootout", "card", "substitution", "pass",
        "chance", "foul", "offside", "set-piece", "var", "other",
    ]
}

/// Une action de match : but, carton, remplacement, tir au but…
public struct ContestAction: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let type: ActionType
    public let family: ActionFamily
    /// Libellé de `type` (« But sur penalty »).
    public let label: String?
    /// Minute de jeu ; le rang dans la séance pour un tir au but.
    public let minute: Double?
    /// Période (« 1ère mi-temps », « Tirs au but »…).
    public let period: String?
    /// Camp de l'action ; pour un but contre son camp, le camp crédité. `nil` sans équipe (VAR).
    public let side: Side?
    /// Auteur : buteur, joueur averti, joueur entrant…
    public let person: PersonRef?
    /// Seconde personne : joueur sortant d'un remplacement.
    public let relatedPerson: PersonRef?
    public let occurredAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, type, family, label, minute, period, side, person, relatedPerson, occurredAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(ActionType.self, forKey: .type)
        family = try container.decode(ActionFamily.self, forKey: .family)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        minute = try container.decodeIfPresent(Double.self, forKey: .minute)
        period = try container.decodeIfPresent(String.self, forKey: .period)
        side = try container.decodeIfPresent(Side.self, forKey: .side)
        person = try container.decodeIfPresent(PersonRef.self, forKey: .person)
        relatedPerson = try container.decodeIfPresent(PersonRef.self, forKey: .relatedPerson)
        occurredAt = try IdalgoDate.decode(container, .occurredAt)
    }

    init(
        id: String, type: ActionType, family: ActionFamily, label: String? = nil, minute: Double?,
        period: String?, side: Side?, person: PersonRef?, relatedPerson: PersonRef? = nil
    ) {
        self.id = id
        self.type = type
        self.family = family
        self.label = label
        self.minute = minute
        self.period = period
        self.side = side
        self.person = person
        self.relatedPerson = relatedPerson
        occurredAt = nil
    }
}

/// Coordonnées sur le terrain, en % : `x` de la largeur (0 : gauche), `y` de la longueur (0 : le
/// but de l'équipe).
public struct PitchPosition: Decodable, Sendable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Un joueur d'une composition ; `position` vaut `nil` pour un remplaçant.
public struct LineupPlayer: Decodable, Sendable, Hashable {
    public let person: PersonRef
    public let shirt: Int?
    public let captain: Bool
    public let position: PitchPosition?
    /// Poste (« Gardien », « Milieu »…).
    public let positionLabel: String?
}

/// Composition d'un camp : système, titulaires, remplaçants, entraîneur.
public struct Lineup: Decodable, Sendable, Hashable {
    public let competitor: ContestCompetitor
    /// Système de jeu (« 4-3-3 »).
    public let formation: String?
    public let starters: [LineupPlayer]
    public let substitutes: [LineupPlayer]
    public let coach: PersonRef?
}
