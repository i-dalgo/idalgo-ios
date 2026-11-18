/// Classement général, à domicile ou à l'extérieur.
public enum StandingSplit: String, Decodable, Sendable, CaseIterable {
    case overall, home, away
}

/// Classement d'une saison ; sa forme dépend de `kind`. Une forme encore inconnue du SDK se
/// décode en `.unsupported` sans faire échouer la réponse.
public enum Standings: Decodable, Sendable, Hashable {
    /// Classement aux points (football, rugby, handball…).
    case leagueTable(LeagueTable)
    /// Classement au pourcentage de victoires (NBA…).
    case winPercentage(WinPercentageTable)
    /// Forme que cette version du SDK ne sait pas afficher.
    case unsupported(kind: String)

    private enum CodingKeys: String, CodingKey { case kind }

    public init(from decoder: any Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .kind)
        switch kind {
        case "league-table": self = .leagueTable(try LeagueTable(from: decoder))
        case "win-percentage": self = .winPercentage(try WinPercentageTable(from: decoder))
        default: self = .unsupported(kind: kind)
        }
    }
}

/// Un classement d'une forme donnée : ses colonnes, dans l'ordre, et ses poules.
public struct StandingsTable<Stats: StandingStats>: Decodable, Sendable, Hashable {
    public let sport: Sport?
    public let competition: CompetitionRef
    public let season: SeasonRef
    public let split: StandingSplit
    /// Statistiques à afficher, dans l'ordre. Une clé inconnue du SDK est ignorée.
    public let columns: [Stats.Column]
    public let groups: [StandingGroup<Stats>]

    private enum CodingKeys: String, CodingKey { case sport, competition, season, split, columns, groups }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sport = try container.decodeIfPresent(Sport.self, forKey: .sport)
        competition = try container.decode(CompetitionRef.self, forKey: .competition)
        season = try container.decode(SeasonRef.self, forKey: .season)
        split = try container.decode(StandingSplit.self, forKey: .split)
        columns = try container.decode([String].self, forKey: .columns).compactMap(Stats.Column.init(rawValue:))
        groups = try container.decode([StandingGroup<Stats>].self, forKey: .groups)
    }
}

public typealias LeagueTable = StandingsTable<LeagueTableStats>
public typealias WinPercentageTable = StandingsTable<WinPercentageStats>

/// Une poule et son classement après `day` ; `id` vaut `nil` pour une phase sans poule.
public struct StandingGroup<Stats: StandingStats>: Decodable, Sendable, Hashable {
    public let id: String?
    public let name: String?
    public let day: DayRef
    public let rows: [StandingRow<Stats>]
}

/// Une ligne du classement : place, évolution depuis la journée précédente, équipe et statistiques.
public struct StandingRow<Stats: StandingStats>: Decodable, Sendable, Hashable {
    public let position: Int
    /// Places gagnées (positif) ou perdues (négatif) depuis la journée précédente.
    public let evolution: Int?
    public let competitor: TeamCompetitor
    public let stats: Stats
}
