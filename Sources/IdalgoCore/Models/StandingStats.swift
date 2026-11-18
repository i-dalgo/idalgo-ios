/// Statistiques d'une ligne de classement, lisibles colonne par colonne.
public protocol StandingStats: Decodable, Sendable, Hashable {
    associatedtype Column: StandingColumn
    /// Valeur d'une colonne.
    func value(for column: Column) -> Double
}

/// Clé d'une statistique de classement, telle que l'API la nomme dans `columns`.
public protocol StandingColumn: RawRepresentable<String>, Sendable, Hashable, CaseIterable {}

/// Classement aux points. `scored` / `conceded` : buts ou points selon le sport.
public struct LeagueTableStats: StandingStats {
    public let points: Double
    public let played: Int
    public let won: Int
    public let drawn: Int
    public let lost: Int
    public let scored: Int
    public let conceded: Int
    public let difference: Int

    public enum Column: String, StandingColumn {
        case points, played, won, drawn, lost, scored, conceded, difference
    }

    public func value(for column: Column) -> Double {
        switch column {
        case .points: points
        case .played: Double(played)
        case .won: Double(won)
        case .drawn: Double(drawn)
        case .lost: Double(lost)
        case .scored: Double(scored)
        case .conceded: Double(conceded)
        case .difference: Double(difference)
        }
    }
}

/// Classement au pourcentage de victoires (NBA…).
public struct WinPercentageStats: StandingStats {
    public let played: Int
    public let won: Int
    public let lost: Int
    /// Part de victoires, de 0 à 1.
    public let winPct: Double
    /// Retard sur le premier de la poule, en matchs.
    public let gamesBehind: Double

    public enum Column: String, StandingColumn {
        case played, won, lost, winPct, gamesBehind
    }

    public func value(for column: Column) -> Double {
        switch column {
        case .played: Double(played)
        case .won: Double(won)
        case .lost: Double(lost)
        case .winPct: winPct
        case .gamesBehind: gamesBehind
        }
    }
}
