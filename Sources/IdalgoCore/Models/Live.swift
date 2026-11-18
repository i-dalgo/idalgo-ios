import Foundation

/// Réponse d'une route live : ses données et le délai avant de la relire.
public struct LiveUpdate<T: Sendable>: Sendable {
    public let data: T
    /// Secondes avant la relecture suivante ; `nil` quand plus rien ne bougera (arrêter de relire).
    public let pollAfter: Int?

    public init(data: T, pollAfter: Int?) {
        self.data = data
        self.pollAfter = pollAfter
    }
}

extension LiveUpdate: Equatable where T: Equatable {}
extension LiveUpdate: Hashable where T: Hashable {}

/// Enveloppe d'une route live : `{ data, meta: { pollAfter, … }, links }`.
struct LiveEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let pollAfter: Int?
    }

    let data: T
    let meta: Meta
}

/// Un camp d'un duel en direct : son score.
public struct LiveSide: Decodable, Sendable, Hashable {
    public let score: Double?
}

/// La part d'un contest qui bouge pendant qu'il se joue.
public enum LiveContest: Decodable, Sendable, Hashable {
    case headToHead(LiveHeadToHead)
    case ranked(LiveRanked)
    case unsupported(type: String)

    private enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "head-to-head": self = .headToHead(try LiveHeadToHead(from: decoder))
        case "ranked": self = .ranked(try LiveRanked(from: decoder))
        default: self = .unsupported(type: type)
        }
    }
}

private enum LiveKeys: String, CodingKey { case id, sport, startsAt, status, statusLabel, home, away, entries }

/// Duel en direct : statut, libellé, heure et scores.
public struct LiveHeadToHead: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let sport: Sport
    public let startsAt: Date?
    public let status: ContestStatus
    public let statusLabel: String?
    public let home: LiveSide
    public let away: LiveSide

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: LiveKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sport = try container.decode(Sport.self, forKey: .sport)
        startsAt = try IdalgoDate.decode(container, .startsAt)
        status = try container.decode(ContestStatus.self, forKey: .status)
        statusLabel = try container.decodeIfPresent(String.self, forKey: .statusLabel)
        home = try container.decode(LiveSide.self, forKey: .home)
        away = try container.decode(LiveSide.self, forKey: .away)
    }
}

/// Épreuve classée en direct : le podium du moment.
public struct LiveRanked: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let sport: Sport
    public let startsAt: Date?
    public let status: ContestStatus
    public let statusLabel: String?
    public let entries: [RankedEntry]

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: LiveKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sport = try container.decode(Sport.self, forKey: .sport)
        startsAt = try IdalgoDate.decode(container, .startsAt)
        status = try container.decode(ContestStatus.self, forKey: .status)
        statusLabel = try container.decodeIfPresent(String.self, forKey: .statusLabel)
        entries = try container.decode([RankedEntry].self, forKey: .entries)
    }
}
