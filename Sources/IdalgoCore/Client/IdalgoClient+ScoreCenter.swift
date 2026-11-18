import Foundation

extension IdalgoClient {
    /// Chemin du module Score Center ; sa route live est `…/live`.
    static let scoreCenterPath = "/modules/score-center/v1"

    /// Matchs d'un sport sur un jour, groupés par compétition (`GET /modules/score-center/v1`).
    /// - Parameters:
    ///   - sport: id du sport (`102` : football).
    ///   - date: jour `AAAA-MM-JJ` dans `timeZone` ; par défaut, aujourd'hui.
    ///   - competitions: ids des compétitions, dans l'ordre des blocs ; vide : la liste par défaut du sport.
    ///   - timeZone: fuseau IANA qui borne le jour et l'heure des matchs ; par défaut, celui de l'appareil.
    public func scoreCenter(
        sport: String,
        date: String? = nil,
        competitions: [String] = [],
        timeZone: String? = nil
    ) async throws -> ScoreCenter {
        try await get(Self.scoreCenterPath, query: scoreCenterQuery(sport, date, competitions, timeZone))
    }

    /// Ce qui bouge sur ce jour (`GET /modules/score-center/v1/live`) et le délai avant de relire.
    public func scoreCenterLive(
        sport: String,
        date: String? = nil,
        competitions: [String] = [],
        timeZone: String? = nil
    ) async throws -> LiveUpdate<ScoreCenterLive> {
        try await getLive(Self.scoreCenterPath + "/live", query: scoreCenterQuery(sport, date, competitions, timeZone))
    }

    /// Paramètres du module ; le fuseau est toujours envoyé, pour que « aujourd'hui » et les heures
    /// soient ceux du lecteur.
    private func scoreCenterQuery(
        _ sport: String, _ date: String?, _ competitions: [String], _ timeZone: String?
    ) -> [String: String] {
        var query = ["sport": sport, "timeZone": timeZone ?? TimeZone.current.identifier]
        query["date"] = date
        if !competitions.isEmpty { query["competitions"] = competitions.joined(separator: ",") }
        return query
    }
}
