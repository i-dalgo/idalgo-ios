import Foundation

/// Formats de la feuille de match, portés de `apps/ui-kit/src/utils/match-sheet.ts`.
package enum MatchSheetFormat {
    /// Nom d'usage : le nom sans le prénom (« Riccardo Calafiori » → « Calafiori »). Un nom d'un
    /// seul mot reste tel quel.
    package static func lastName(_ name: String?) -> String {
        guard let name else { return "—" }
        let words = name.split(whereSeparator: \.isWhitespace)
        return words.count > 1 ? words.dropFirst().joined(separator: " ") : (words.first.map(String.init) ?? name)
    }

    /// « 45’ » ; vide sans minute.
    package static func minute(_ minute: Double?) -> String {
        minute.map { "\(Int($0.rounded()))’" } ?? ""
    }

    /// Nombre décimal à la française (« 2,1 ») ; tiret sans valeur.
    package static func decimal(_ value: Double?, digits: Int = 1) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(digits)f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// « 1-0 » ; tiret sans score.
    package static func frequentScore(_ score: [Double]?) -> String {
        guard let score, score.count == 2 else { return "—" }
        return "\(StandingsFormat.number(score[0]))-\(StandingsFormat.number(score[1]))"
    }

    /// « Premier League 2025/2026 » → « 25/26 », « Coupe du monde 2026 » → « 26 » ; le nom entier sans année.
    package static func shortSeason(_ name: String?) -> String {
        guard let name else { return "—" }
        let years = name.matches(of: /\d{4}/).map { String($0.output.suffix(2)) }
        switch years.count {
        case 0: return name
        case 1: return years[0]
        default: return "\(years[0])/\(years[1])"
        }
    }

    /// Entier avec espaces fines entre milliers : « 60 704 ».
    package static func grouped(_ value: Int) -> String {
        let digits = String(abs(value))
        var groups: [String] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(String(digits[start..<end]), at: 0)
            end = start
        }
        return (value < 0 ? "-" : "") + groups.joined(separator: "\u{202F}")
    }

    /// « samedi 10 octobre 2026 à 15:30 » dans un fuseau.
    package static func dateTime(_ date: Date, timeZone: TimeZone) -> String {
        let day = ScoreCenterFormat.calendarDate(date, timeZone: timeZone)
        let year = day.prefix(4)
        let longDay = ScoreCenterFormat.longDay(day).map { "\($0) \(year)" } ?? day
        return IdalgoStrings.dateAtTime(longDay, ScoreCenterFormat.time(date, timeZone: timeZone))
    }

    /// « 1er • 39 pts » sous le nom d'une équipe ; `nil` sans classement ou sans l'équipe.
    package static func standingLine(_ standings: Standings?, teamId: String) -> String? {
        switch standings {
        case let .leagueTable(table):
            guard let row = row(of: teamId, in: table) else { return nil }
            return "\(IdalgoStrings.ordinal(row.position)) • \(StandingsFormat.number(row.stats.points)) pts"
        case let .winPercentage(table):
            guard let row = row(of: teamId, in: table) else { return nil }
            return "\(IdalgoStrings.ordinal(row.position)) • \(decimal(row.stats.winPct * 100)) %"
        case .unsupported, nil:
            return nil
        }
    }

    private static func row<Stats>(of teamId: String, in table: StandingsTable<Stats>) -> StandingRow<Stats>? {
        table.groups.lazy.compactMap { $0.rows.first { $0.competitor.id == teamId } }.first
    }
}
