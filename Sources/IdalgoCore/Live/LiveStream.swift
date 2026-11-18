import Foundation

/// Un document (jour du Score Center, feuille de match) suivi en direct : lu une fois, puis relu
/// sur sa route live au rythme de `pollAfter`. Une seule mise en œuvre, pour les widgets comme pour
/// les écrans d'une app (`IdalgoClient.scoreCenterUpdates`, `matchSheetUpdates`).
enum LiveStream {
    /// Documents gardés pour un lecteur lent : le dernier seulement (le SDK), ou tous (tests de
    /// cadence, qui comptent chaque document).
    enum Buffering: Sendable {
        case newest, all
    }

    /// Après une erreur passagère (réseau, 5xx, 408, 429) pendant le direct : nouvel essai, moins souvent.
    static let retryAfterError: Duration = .seconds(30)

    /// Le flux : le document lu, puis le document après chaque lecture live. Il se termine quand
    /// `pollAfter` vaut `nil`, ou aussitôt si rien ne se joue (ni ne se jouera) ; il échoue sur une
    /// erreur à la première lecture ou sur une erreur permanente pendant le direct. Arrêter de le
    /// lire (tâche annulée) arrête les requêtes. Un lecteur lent ne reçoit que le dernier document :
    /// les précédents, périmés, ne s'accumulent pas.
    static func make<Document: Sendable, Live: Sendable>(
        buffering: Buffering = .newest,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        load: @escaping @Sendable () async throws -> Document,
        startDelay: @escaping @Sendable (Document, Date) -> TimeInterval?,
        fetchLive: @escaping @Sendable (Document) async throws -> LiveUpdate<Live>,
        merge: @escaping @Sendable (Document, Live) -> Document
    ) -> AsyncThrowingStream<Document, Error> {
        AsyncThrowingStream(bufferingPolicy: buffering == .newest ? .bufferingNewest(1) : .unbounded) { continuation in
            let task = Task {
                do {
                    let document = try await load()
                    continuation.yield(document)
                    if let delay = startDelay(document, now()) {
                        try await follow(
                            document, after: .seconds(delay), sleep: sleep, fetchLive: fetchLive, merge: merge
                        ) { continuation.yield($0) }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Relit le direct après `delay`, reporte chaque lecture sur le document et le transmet, puis
    /// attend `pollAfter` ; s'arrête quand `pollAfter` vaut `nil`. Une erreur passagère garde le
    /// dernier document et réessaie après `retryAfterError` ; une autre erreur est levée.
    static func follow<Document: Sendable, Live: Sendable>(
        _ document: Document,
        after delay: Duration,
        sleep: @Sendable (Duration) async throws -> Void,
        fetchLive: @Sendable (Document) async throws -> LiveUpdate<Live>,
        merge: @Sendable (Document, Live) -> Document,
        emit: @Sendable (Document) -> Void
    ) async throws {
        var document = document
        var wait = delay
        while true {
            try await sleep(wait)
            do {
                let update = try await fetchLive(document)
                document = merge(document, update.data)
                emit(document)
                guard let pollAfter = update.pollAfter else { return }
                wait = .seconds(pollAfter)
            } catch let error as IdalgoError where error.isRetryable {
                wait = retryAfterError
            }
        }
    }
}
