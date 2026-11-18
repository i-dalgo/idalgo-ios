import Foundation

/// Envoi d'une requête HTTP. Le SDK passe par `URLSessionTransport` ; un test ou une app peut
/// fournir le sien (journalisation, bouchon). Toute erreur levée ici est rendue à l'app en
/// `IdalgoError.network`.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Transport par `URLSession`, sans le cache d'URLSession : le client tient le sien (`max-age`, `ETag`).
///
/// `URLSessionTransport.shared` sert à tous les clients créés sans transport, dont celui de
/// `Idalgo.configure` : reconfigurer le SDK garde la même session (connexions réutilisées). Un
/// transport créé avec `init(timeout:)` a sa propre session, fermée quand il n'est plus utilisé.
public struct URLSessionTransport: HTTPTransport {
    /// Délai maximal d'une requête par défaut, en secondes.
    public static let timeout: TimeInterval = 10

    /// Transport partagé du SDK, délai par défaut.
    public static let shared = URLSessionTransport()

    /// Délai maximal d'une requête de ce transport, en secondes.
    public let timeout: TimeInterval
    private let owner: SessionOwner

    public init(timeout: TimeInterval = URLSessionTransport.timeout) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        owner = SessionOwner(session: URLSession(configuration: configuration))
    }

    /// Session de ce transport (aussi celle des logos des composants).
    var session: URLSession { owner.session }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: prepared(request))
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    /// La requête avec le délai de ce transport : celui d'une `URLRequest` remplacerait celui
    /// de la session.
    func prepared(_ request: URLRequest) -> URLRequest {
        var request = request
        request.timeoutInterval = timeout
        return request
    }
}

/// Garde la session d'un transport et la ferme quand plus aucune copie du transport ne la tient
/// (une `URLSession` non invalidée resterait en mémoire).
private final class SessionOwner: Sendable {
    let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    deinit {
        session.finishTasksAndInvalidate()
    }
}
