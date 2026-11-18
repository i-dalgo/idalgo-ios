import Foundation
import os

extension IdalgoClient {
    /// Taille des pages lues par `competitions(sport:)` (le maximum de l'API).
    static let competitionsPageSize = 100

    /// Toutes les compétitions, ou celles d'un sport (`GET /v1/competitions`, pages suivies jusqu'à
    /// la dernière).
    /// - Parameter sport: id du sport (`102` : football) ; `nil` : tous les sports.
    /// - Throws: `IdalgoError`, ou `CancellationError` si la tâche est annulée.
    public func competitions(sport: String? = nil) async throws -> [Competition] {
        var query = ["limit": String(Self.competitionsPageSize)]
        query["sport"] = sport
        var competitions: [Competition] = []
        while true {
            let page: ListEnvelope<Competition> = try await getList("/v1/competitions", query: query)
            competitions += page.data
            guard let cursor = page.meta.cursor, !page.data.isEmpty else { return competitions }
            query["cursor"] = cursor
        }
    }

    /// Une compétition (`GET /v1/competitions?ids=`).
    /// - Parameter id: id de la compétition (`103` : Ligue 1).
    /// - Throws: `IdalgoError.api` 404 (`not-found`) si elle n'existe pas ; `IdalgoError`, ou
    ///   `CancellationError` si la tâche est annulée.
    public func competition(id: String) async throws -> Competition {
        let page: ListEnvelope<Competition> = try await getList("/v1/competitions", query: ["ids": id])
        guard let competition = page.data.first(where: { $0.id == id }) else {
            throw IdalgoError.api(status: 404, code: .notFound, detail: IdalgoStrings.competitionNotFound)
        }
        return competition
    }

    /// Id de la saison en cours d'une compétition (`currentSeason.id`), lu une fois par client.
    /// - Throws: `IdalgoError.api` 404 (`not-found`) si la compétition n'existe pas ou n'a pas de
    ///   saison en cours.
    package func currentSeasonID(competition id: String) async throws -> String {
        if let season = currentSeasons.withLock({ $0[id] }) { return season }
        guard let season = try await competition(id: id).currentSeason?.id else {
            throw IdalgoError.api(status: 404, code: .notFound, detail: IdalgoStrings.noCurrentSeason)
        }
        currentSeasons.withLock { $0[id] = season }
        return season
    }
}
