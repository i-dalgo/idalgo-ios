import Foundation

/// Statut normalisé d'un contest. Liste ouverte : un statut inconnu du SDK se décode tel quel
/// (`isKnown` faux) et s'affiche avec `statusLabel`.
public struct ContestStatus: RawRepresentable, Hashable, Sendable, Codable {
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

    public static let scheduled = ContestStatus(rawValue: "scheduled")
    public static let live = ContestStatus(rawValue: "live")
    public static let finished = ContestStatus(rawValue: "finished")
    public static let postponed = ContestStatus(rawValue: "postponed")
    public static let cancelled = ContestStatus(rawValue: "cancelled")

    /// Un des statuts que cette version du SDK sait afficher.
    public var isKnown: Bool {
        [.scheduled, .live, .finished, .postponed, .cancelled].contains(self)
    }
}

/// Un match ou une épreuve ; sa forme dépend de `type`. Une forme inconnue du SDK se décode en
/// `.unsupported` sans faire échouer la réponse.
public enum Contest: Decodable, Sendable, Hashable, Identifiable {
    /// Un duel : match, combat.
    case headToHead(HeadToHeadContest)
    /// Une épreuve classée : course, concours.
    case ranked(RankedContest)
    /// Forme que cette version du SDK ne sait pas afficher.
    case unsupported(type: String, id: String)

    private enum CodingKeys: String, CodingKey { case type, id }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "head-to-head": self = .headToHead(try HeadToHeadContest(from: decoder))
        case "ranked": self = .ranked(try RankedContest(from: decoder))
        default: self = .unsupported(type: type, id: try container.decode(String.self, forKey: .id))
        }
    }

    public var id: String {
        switch self {
        case let .headToHead(contest): contest.id
        case let .ranked(contest): contest.id
        case let .unsupported(_, id): id
        }
    }

    /// Statut ; `nil` pour une forme inconnue.
    public var status: ContestStatus? {
        switch self {
        case let .headToHead(contest): contest.status
        case let .ranked(contest): contest.status
        case .unsupported: nil
        }
    }

    /// Heure de début ; `nil` si inconnue ou pour une forme inconnue.
    public var startsAt: Date? {
        switch self {
        case let .headToHead(contest): contest.startsAt
        case let .ranked(contest): contest.startsAt
        case .unsupported: nil
        }
    }
}

/// Un camp d'un duel et son score principal (`nil` tant que le contest n'a pas commencé).
public struct ContestSide: Decodable, Sendable, Hashable {
    public let competitor: ContestCompetitor
    public internal(set) var score: Double?
}

/// Champs communs aux deux formes de contest.
private enum ContestKeys: String, CodingKey {
    case id, sport, competition, season, phase, group, day, startsAt, status, statusLabel, venue
    case home, away, name, entries, entryCount
}

/// Un duel : match, combat.
public struct HeadToHeadContest: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let sport: Sport
    public let competition: CompetitionRef
    public let season: SeasonRef
    public let phase: PhaseRef?
    public let group: GroupRef?
    public let day: DayRef?
    public internal(set) var startsAt: Date?
    public internal(set) var status: ContestStatus
    /// Libellé exact de la source (« Mi-temps », « 45e »…).
    public internal(set) var statusLabel: String?
    public let venue: VenueRef?
    public internal(set) var home: ContestSide
    public internal(set) var away: ContestSide

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ContestKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sport = try container.decode(Sport.self, forKey: .sport)
        competition = try container.decode(CompetitionRef.self, forKey: .competition)
        season = try container.decode(SeasonRef.self, forKey: .season)
        phase = try container.decodeIfPresent(PhaseRef.self, forKey: .phase)
        group = try container.decodeIfPresent(GroupRef.self, forKey: .group)
        day = try container.decodeIfPresent(DayRef.self, forKey: .day)
        startsAt = try IdalgoDate.decode(container, .startsAt)
        status = try container.decode(ContestStatus.self, forKey: .status)
        statusLabel = try container.decodeIfPresent(String.self, forKey: .statusLabel)
        venue = try container.decodeIfPresent(VenueRef.self, forKey: .venue)
        home = try container.decode(ContestSide.self, forKey: .home)
        away = try container.decode(ContestSide.self, forKey: .away)
    }
}

/// Une épreuve classée. Dans une liste, `entries` ne contient que le podium ; `entryCount` compte
/// tous les concurrents.
public struct RankedContest: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let sport: Sport
    public let competition: CompetitionRef
    public let season: SeasonRef
    public let phase: PhaseRef?
    public let group: GroupRef?
    public let day: DayRef?
    public internal(set) var startsAt: Date?
    public internal(set) var status: ContestStatus
    public internal(set) var statusLabel: String?
    public let venue: VenueRef?
    public let name: String?
    public internal(set) var entries: [RankedEntry]
    public let entryCount: Int

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: ContestKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sport = try container.decode(Sport.self, forKey: .sport)
        competition = try container.decode(CompetitionRef.self, forKey: .competition)
        season = try container.decode(SeasonRef.self, forKey: .season)
        phase = try container.decodeIfPresent(PhaseRef.self, forKey: .phase)
        group = try container.decodeIfPresent(GroupRef.self, forKey: .group)
        day = try container.decodeIfPresent(DayRef.self, forKey: .day)
        startsAt = try IdalgoDate.decode(container, .startsAt)
        status = try container.decode(ContestStatus.self, forKey: .status)
        statusLabel = try container.decodeIfPresent(String.self, forKey: .statusLabel)
        venue = try container.decodeIfPresent(VenueRef.self, forKey: .venue)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        entries = try container.decode([RankedEntry].self, forKey: .entries)
        entryCount = try container.decode(Int.self, forKey: .entryCount)
    }
}

/// Un concurrent d'une épreuve classée ; `position` vaut `nil` pour un non classé.
public struct RankedEntry: Decodable, Sendable, Hashable {
    public let position: Int?
    public let competitor: ContestCompetitor
    public let result: ContestResult?
    /// `gold`, `silver` ou `bronze`.
    public let medal: String?
}

/// Résultat d'un concurrent d'une épreuve classée ; `display` est déjà formaté (« 26:43.79 »).
public struct ContestResult: Decodable, Sendable, Hashable {
    public let value: Double
    /// `time` (millisecondes), `points`, `distance`, `other` ; liste ouverte.
    public let unit: String
    public let display: String
}
