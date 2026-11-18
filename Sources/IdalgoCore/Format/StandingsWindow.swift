/// Les lignes d'une poule à montrer : toutes, les `limit` premières, et / ou `around` lignes de part
/// et d'autre de chaque équipe mise en avant. Une coupure marque les lignes sautées entre deux
/// morceaux (« Top 3 … 7e 8e 9e »).
package enum StandingsWindow {
    package enum Item: Sendable, Equatable, Identifiable {
        case row(StandingsPresentation.Row)
        /// Lignes masquées entre deux morceaux ; `after` : id de la ligne qui la précède.
        case gap(after: String)

        package var id: String {
            switch self {
            case let .row(row): row.id
            case let .gap(after): "gap-\(after)"
            }
        }
    }

    /// - Parameters:
    ///   - limit: les N premières lignes ; `nil` (ou 0) : pas de coupe par le haut.
    ///   - around: lignes gardées de part et d'autre de chaque équipe de `highlight` ; sans équipe
    ///     mise en avant dans la poule, `limit` seul s'applique (toutes les lignes sans `limit`).
    package static func items(
        _ rows: [StandingsPresentation.Row],
        highlight: Set<String>,
        limit: Int?,
        around: Int?
    ) -> [Item] {
        let limit = limit.flatMap { $0 > 0 ? $0 : nil }
        let around = around.flatMap { $0 >= 0 ? $0 : nil }
        guard limit != nil || around != nil else { return rows.map(Item.row) }
        var kept = Set<Int>()
        if let limit { kept.formUnion(0..<min(limit, rows.count)) }
        if let around {
            let anchors = rows.indices.filter { highlight.contains(rows[$0].id) }
            if anchors.isEmpty, limit == nil { return rows.map(Item.row) }
            for anchor in anchors {
                kept.formUnion(max(anchor - around, 0)...min(anchor + around, rows.count - 1))
            }
        }
        var items: [Item] = []
        var previous: Int?
        for index in kept.sorted() {
            if let previous, index > previous + 1 { items.append(.gap(after: rows[previous].id)) }
            items.append(.row(rows[index]))
            previous = index
        }
        return items
    }
}
