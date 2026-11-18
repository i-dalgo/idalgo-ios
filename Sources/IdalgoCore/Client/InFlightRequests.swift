import Foundation

/// Requêtes en cours, par adresse : deux lectures identiques lancées en même temps (deux vues sur
/// le même classement, un widget et un écran maison) partagent un seul appel réseau.
///
/// L'appel partagé ne s'annule que quand tous ceux qui l'attendent sont annulés ; un appelant
/// annulé alors que d'autres attendent encore reçoit `CancellationError` une fois l'appel fini.
actor InFlightRequests {
    private final class Flight {
        let task: Task<Data, any Error>
        var waiters = 0
        var cancelledWaiters = 0

        init(task: Task<Data, any Error>) {
            self.task = task
        }
    }

    private var flights: [URL: Flight] = [:]

    /// Le résultat de `operation` pour `url`, lancée seulement si aucun appel n'est en cours.
    func data(for url: URL, operation: @escaping @Sendable () async throws -> Data) async throws -> Data {
        let flight: Flight
        if let current = flights[url] {
            flight = current
        } else {
            flight = Flight(task: Task { try await operation() })
            flights[url] = flight
        }
        flight.waiters += 1
        defer { leave(flight, url: url) }
        let task = flight.task
        let id = ObjectIdentifier(flight)
        let data = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            Task { await self.cancelled(url: url, flight: id) }
        }
        try Task.checkCancellation()
        return data
    }

    /// Appelants en attente d'un appel pour `url` (tests).
    func waiters(for url: URL) -> Int {
        flights[url]?.waiters ?? 0
    }

    private func leave(_ flight: Flight, url: URL) {
        flight.waiters -= 1
        if flight.waiters == 0, flights[url] === flight { flights[url] = nil }
    }

    /// Un appelant annulé : l'appel s'annule si plus personne d'autre ne l'attend. Tant que
    /// l'appel court, aucun appelant ne part : les annulés restent comptés dans `waiters`.
    private func cancelled(url: URL, flight id: ObjectIdentifier) {
        guard let flight = flights[url], ObjectIdentifier(flight) == id else { return }
        flight.cancelledWaiters += 1
        if flight.cancelledWaiters >= flight.waiters { flight.task.cancel() }
    }
}
