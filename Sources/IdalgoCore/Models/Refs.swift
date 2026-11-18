import Foundation

/// Une compétition (Ligue 1, NBA…), son nom dans la langue demandée et son logo.
public struct CompetitionRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let logo: Logo?
}

/// Une saison de compétition (« Ligue 1 2026/2027 »).
public struct SeasonRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
}

/// Une journée de la saison et sa date de calendrier (`AAAA-MM-JJ`).
public struct DayRef: Decodable, Sendable, Hashable {
    public let id: String
    public let date: String?
}

/// Une phase de la saison (saison régulière, play-offs…).
public struct PhaseRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
}

/// Une poule d'une phase.
public struct GroupRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
}

/// Un stade ou un site.
public struct VenueRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
}

/// Une personne (athlète, joueur, arbitre) et son portrait.
public struct PersonRef: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
    /// Portrait 5:7 : `small` 50 × 70 px, `large` 100 × 141 px ; peut répondre 404.
    public let photo: Logo?
}

/// Un pays, son code (CIO ou iDalgo) et son drapeau.
public struct Country: Decodable, Sendable, Hashable {
    public let id: String
    public let name: String?
    public let code: String?
    public let flag: CountryFlag?
}

/// Drapeau d'un pays : PNG 16 × 11 px, et SVG au format 3:2.
public struct CountryFlag: Decodable, Sendable, Hashable {
    public let small: IdalgoImage
    public let svg: URL
}

/// Un contest en référence légère : son id et son heure de début.
public struct ContestRef: Decodable, Sendable, Hashable {
    public let id: String
    public let startsAt: Date?

    private enum CodingKeys: String, CodingKey { case id, startsAt }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startsAt = try IdalgoDate.decode(container, .startsAt)
    }
}
