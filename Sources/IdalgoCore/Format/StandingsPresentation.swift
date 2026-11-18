import Foundation

/// Un classement prêt à afficher : en-têtes, cellules formatées et libellés d'accessibilité, quelle
/// que soit sa forme. Les composants n'ont plus qu'à le dessiner.
package struct StandingsPresentation: Sendable, Equatable {
    /// Une colonne de statistique.
    package struct Column: Sendable, Equatable, Identifiable {
        /// Clé de la statistique dans l'API (`points`, `winPct`…).
        package let id: String
        package let header: String
        package let accessibilityName: String
        /// Statistique principale (points, pourcentage), en gras.
        package let isEmphasized: Bool
        /// Caractères du plus long contenu (en-tête compris), pour régler la largeur de la colonne.
        package let characterCount: Int
    }

    /// Ton d'une cellule : neutre, ou positif / négatif (différence).
    package enum Tone: Sendable, Equatable {
        case neutral, positive, negative
    }

    package struct Cell: Sendable, Equatable {
        package let text: String
        package let tone: Tone
    }

    package struct Row: Sendable, Equatable, Identifiable {
        package var id: String { competitor.id }
        package let position: Int
        package let evolution: StandingEvolution?
        package let competitor: TeamCompetitor
        /// Une cellule par colonne, dans l'ordre de `columns`.
        package let cells: [Cell]
        /// « 1er, Paris SG, 23 points ».
        package let accessibilityLabel: String
        /// Toutes les statistiques : « Matchs joués 10, Victoires 7… ».
        package let accessibilityValue: String
    }

    package struct Group: Sendable, Equatable, Identifiable {
        package let id: String
        package let name: String
        /// « Après le 7 novembre 2026 », si la journée a une date.
        package let dayLabel: String?
        package let rows: [Row]
    }

    package let title: String?
    package let competitionLogo: Logo?
    package let split: StandingSplit
    package private(set) var columns: [Column]
    package private(set) var groups: [Group]
    /// Une ligne au moins a bougé depuis la journée précédente.
    package let showsEvolution: Bool

    /// Colonnes gardées par un classement compact aux points, dans l'ordre de l'API : matchs joués,
    /// différence et points.
    package static let compactColumns: Set<String> = ["played", "difference", "points"]
    /// Colonnes compactes d'un classement aux victoires (sans points).
    package static let compactWinColumns: Set<String> = ["won", "lost", "winPct"]

    /// Le même classement réduit aux colonnes compactes ; tel quel s'il n'en a aucune.
    package func compacted() -> StandingsPresentation {
        let keys = columns.contains { $0.id == "points" } ? Self.compactColumns : Self.compactWinColumns
        let kept = columns.indices.filter { keys.contains(columns[$0].id) }
        guard !kept.isEmpty, kept.count < columns.count else { return self }
        var copy = self
        copy.columns = kept.map { columns[$0] }
        copy.groups = groups.map { group in
            Group(id: group.id, name: group.name, dayLabel: group.dayLabel, rows: group.rows.map { row in
                Row(
                    position: row.position,
                    evolution: row.evolution,
                    competitor: row.competitor,
                    cells: kept.map { row.cells[$0] },
                    accessibilityLabel: row.accessibilityLabel,
                    accessibilityValue: row.accessibilityValue
                )
            })
        }
        return copy
    }

    /// `nil` pour une forme de classement que le SDK ne sait pas afficher.
    package init?(_ standings: Standings) {
        switch standings {
        case let .leagueTable(table):
            self.init(table, summary: { stats in [IdalgoStrings.plural(Int(stats.points), "point")] })
        case let .winPercentage(table):
            self.init(table, summary: { stats in
                [IdalgoStrings.plural(stats.won, "victoire"), IdalgoStrings.plural(stats.lost, "défaite")]
            })
        case .unsupported:
            return nil
        }
    }

    private init<Stats: StandingStats>(_ table: StandingsTable<Stats>, summary: (Stats) -> [String]) {
        let columns = table.columns
        let groups = table.groups.enumerated().map { index, group in
            Group(
                id: group.id ?? String(index),
                name: group.name ?? IdalgoStrings.unnamedGroup(index + 1),
                dayLabel: group.day.date.flatMap(StandingsFormat.calendarDate).map(IdalgoStrings.afterDay),
                rows: group.rows.map { Self.row($0, columns: columns, summary: summary) }
            )
        }
        title = table.season.name ?? table.competition.name
        competitionLogo = table.competition.logo
        split = table.split
        self.columns = columns.enumerated().map { index, column in
            let label = StandingColumnLabel(key: column.rawValue)
            let longest = groups.flatMap(\.rows).map { $0.cells[index].text.count }.max() ?? 0
            return Column(
                id: column.rawValue,
                header: label.header,
                accessibilityName: label.accessibilityName,
                isEmphasized: label.isEmphasized,
                characterCount: max(longest, label.header.count)
            )
        }
        self.groups = groups
        showsEvolution = groups.contains { $0.rows.contains { $0.evolution != nil } }
    }

    private static func row<Stats: StandingStats>(
        _ row: StandingRow<Stats>,
        columns: [Stats.Column],
        summary: (Stats) -> [String]
    ) -> Row {
        let evolution = StandingsFormat.evolution(row.evolution)
        let cells = columns.map { cell(key: $0.rawValue, value: row.stats.value(for: $0)) }
        let label = [IdalgoStrings.ordinal(row.position), row.competitor.name ?? "—"]
            + summary(row.stats)
            + [evolution?.accessibilityLabel].compactMap { $0 }
        let value = zip(columns, cells).map { column, cell in
            "\(StandingColumnLabel(key: column.rawValue).accessibilityName) \(cell.text)"
        }
        return Row(
            position: row.position,
            evolution: evolution,
            competitor: row.competitor,
            cells: cells,
            accessibilityLabel: label.joined(separator: ", "),
            accessibilityValue: value.joined(separator: ", ")
        )
    }

    static func cell(key: String, value: Double) -> Cell {
        switch key {
        case "winPct": Cell(text: StandingsFormat.winPercentage(value), tone: .neutral)
        case "gamesBehind": Cell(text: StandingsFormat.gamesBehind(value), tone: .neutral)
        case "difference":
            Cell(text: StandingsFormat.difference(Int(value)), tone: value > 0 ? .positive : value < 0 ? .negative : .neutral)
        default: Cell(text: StandingsFormat.number(value), tone: .neutral)
        }
    }
}

/// En-tête court et nom complet d'une statistique, repris des widgets web (`configs/columns.ts`).
struct StandingColumnLabel {
    let header: String
    let accessibilityName: String
    let isEmphasized: Bool

    init(key: String) {
        (header, accessibilityName, isEmphasized) = switch key {
        case "points": ("Pts", "Points", true)
        case "played": ("J", "Matchs joués", false)
        case "won": ("V", "Victoires", false)
        case "drawn": ("N", "Nuls", false)
        case "lost": ("D", "Défaites", false)
        case "scored": ("+", "Marqués", false)
        case "conceded": ("\u{2212}", "Encaissés", false)
        case "difference": ("Diff", "Différence", false)
        case "winPct": ("%", "Pourcentage de victoires", true)
        case "gamesBehind": ("Retard", "Retard", false)
        default: (key, key, false)
        }
    }
}
