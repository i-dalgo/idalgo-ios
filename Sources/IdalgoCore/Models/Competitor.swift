/// Une équipe concurrente.
public struct TeamCompetitor: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String?
    /// Logo de l'équipe (football) ; `nil` pour les autres sports.
    public let logo: Logo?

    public init(id: String, name: String?, logo: Logo? = nil) {
        self.id = id
        self.name = name
        self.logo = logo
    }
}

/// Plusieurs athlètes sans équipe (relais, double) ; `name` réunit leurs noms.
public struct CrewCompetitor: Decodable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String?
    public let members: [PersonRef]
}

/// Un concurrent d'un contest : équipe, athlète ou équipage. Un type inconnu du SDK se décode en
/// `.unsupported` sans faire échouer la réponse.
public enum ContestCompetitor: Decodable, Sendable, Hashable {
    case team(TeamCompetitor)
    case person(PersonRef)
    case crew(CrewCompetitor)
    case unsupported(type: String)

    private enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: any Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "team": self = .team(try TeamCompetitor(from: decoder))
        case "person": self = .person(try PersonRef(from: decoder))
        case "crew": self = .crew(try CrewCompetitor(from: decoder))
        default: self = .unsupported(type: type)
        }
    }

    public var id: String? {
        switch self {
        case let .team(team): team.id
        case let .person(person): person.id
        case let .crew(crew): crew.id
        case .unsupported: nil
        }
    }

    public var name: String? {
        switch self {
        case let .team(team): team.name
        case let .person(person): person.name
        case let .crew(crew): crew.name
        case .unsupported: nil
        }
    }

    /// Image à montrer à côté du nom : logo d'une équipe, portrait d'un athlète.
    public var image: Logo? {
        switch self {
        case let .team(team): team.logo
        case let .person(person): person.photo
        case .crew, .unsupported: nil
        }
    }
}
