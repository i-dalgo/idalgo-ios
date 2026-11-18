/// Formatage des statistiques de classement, commun aux composants et aux écrans d'une app.
package enum StandingsFormat {
    /// Signe moins typographique (U+2212).
    static let minus = "\u{2212}"

    /// Pourcentage de victoires à la manière américaine : `.750`, `1.000`, `.000`.
    package static func winPercentage(_ value: Double) -> String {
        let text = String(format: "%.3f", value)
        return text.hasPrefix("0.") ? String(text.dropFirst()) : text
    }

    /// Retard sur le premier : `—` à 0, sinon une décimale au plus (`0,5`, `3`).
    package static func gamesBehind(_ value: Double) -> String {
        value == 0 ? "—" : number(value)
    }

    /// Différence signée : `+12`, `0`, `−3`.
    package static func difference(_ value: Int) -> String {
        value > 0 ? "+\(value)" : value < 0 ? "\(minus)\(-value)" : "0"
    }

    /// Nombre entier tel quel, sinon une décimale avec une virgule (`2,5`).
    package static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }

    /// Évolution d'une place depuis la journée précédente ; `nil` si elle n'a pas bougé.
    package static func evolution(_ value: Int?) -> StandingEvolution? {
        guard let value, value != 0 else { return nil }
        return value > 0 ? .up(value) : .down(-value)
    }

    /// Date de calendrier (`AAAA-MM-JJ`) en toutes lettres : « 7 novembre 2026 ».
    package static func calendarDate(_ date: String) -> String? {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]) else { return nil }
        let day = parts[2] == 1 ? "1er" : String(parts[2])
        return "\(day) \(IdalgoStrings.months[parts[1] - 1]) \(parts[0])"
    }
}

/// Places gagnées ou perdues depuis la journée précédente.
package enum StandingEvolution: Sendable, Equatable {
    case up(Int)
    case down(Int)

    /// « gagne 2 places », « perd 1 place ».
    package var accessibilityLabel: String {
        switch self {
        case let .up(count): IdalgoStrings.placesGained(count)
        case let .down(count): IdalgoStrings.placesLost(count)
        }
    }
}
