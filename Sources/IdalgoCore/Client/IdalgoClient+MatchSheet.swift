extension IdalgoClient {
    /// Chemin du module Feuille de match ; sa route live est `…/live`.
    static let matchSheetPath = "/modules/match-sheet/v1"

    /// Feuille d'un match (`GET /modules/match-sheet/v1?contest=`).
    public func matchSheet(contest: String) async throws -> MatchSheet {
        try await get(Self.matchSheetPath, query: ["contest": contest])
    }

    /// Ce qui bouge sur la feuille (`GET /modules/match-sheet/v1/live?contest=`) et le délai avant de relire.
    public func matchSheetLive(contest: String) async throws -> LiveUpdate<MatchSheetLive> {
        try await getLive(Self.matchSheetPath + "/live", query: ["contest": contest])
    }
}
