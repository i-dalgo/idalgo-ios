/// Une compétition (`/v1/competitions`) : son nom, son logo, son sport et sa saison en cours.
public struct Competition: Decodable, Sendable, Hashable, Identifiable {
    /// Id de la compétition (`103` : Ligue 1).
    public let id: String
    /// Nom, dans la langue demandée.
    public let name: String?
    /// Logo de la compétition (football) ; `nil` pour les autres sports.
    public let logo: Logo?
    /// Sport de la compétition.
    public let sport: Sport?
    /// Saison en cours : celle des classements (`standings(season:)`) ; `nil` quand la source n'en
    /// désigne pas.
    public let currentSeason: SeasonRef?
}

/// Enveloppe d'une liste paginée : `data`, et le curseur de la page suivante (`meta.cursor`).
struct ListEnvelope<T: Decodable & Sendable>: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let cursor: String?
    }

    let data: [T]
    let meta: Meta
}
