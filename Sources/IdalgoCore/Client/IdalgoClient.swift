import Foundation
import os

/// Client de l'API iDalgo `/v1` : construit les requêtes, garde les réponses en cache mémoire,
/// partage les lectures identiques en cours, retente sur erreur passagère et décode le contrat
/// public.
///
/// Utilisable seul pour bâtir ses propres écrans :
/// ```swift
/// let client = IdalgoClient(configuration: IdalgoConfiguration(lang: "en"))
/// let standings = try await client.standings(season: "374703", split: .home)
/// ```
///
/// Chaque méthode ne lève que `IdalgoError`, ou `CancellationError` si la tâche est annulée.
public final class IdalgoClient: Sendable {
    public let configuration: IdalgoConfiguration
    let transport: any HTTPTransport
    private let retryPolicy: RetryPolicy
    private let identity: AppIdentity
    private let cache = ResponseCache()
    let inFlight = InFlightRequests()
    let now: @Sendable () -> Date
    let sleep: @Sendable (Duration) async throws -> Void
    /// Documents gardés par les flux du direct pour un lecteur lent.
    let liveBuffering: LiveStream.Buffering
    /// Saison en cours de chaque compétition déjà résolue (`currentSeasonID(competition:)`).
    let currentSeasons = OSAllocatedUnfairLock<[String: String]>(initialState: [:])

    /// - Parameters:
    ///   - configuration: clé, adresse et langue ; par défaut celle de `Idalgo.configure`. Une
    ///     clé secrète `idl_sk_…` n'est jamais envoyée (voir `IdalgoConfiguration.apiKey`).
    ///   - transport: par défaut la session partagée du SDK.
    ///   - retryPolicy: nouvelles tentatives sur erreur passagère.
    public convenience init(
        configuration: IdalgoConfiguration = Idalgo.configuration,
        transport: any HTTPTransport = URLSessionTransport.shared,
        retryPolicy: RetryPolicy = .standard
    ) {
        self.init(
            configuration: configuration,
            transport: transport,
            retryPolicy: retryPolicy,
            now: { Date() },
            sleep: { try await Task.sleep(for: $0) }
        )
    }

    init(
        configuration: IdalgoConfiguration,
        transport: any HTTPTransport,
        retryPolicy: RetryPolicy,
        identity: AppIdentity = .current,
        liveBuffering: LiveStream.Buffering = .newest,
        now: @escaping @Sendable () -> Date,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.configuration = Idalgo.withoutSecretKey(configuration)
        self.transport = transport
        self.retryPolicy = retryPolicy
        self.identity = identity
        self.liveBuffering = liveBuffering
        self.now = now
        self.sleep = sleep
    }

    /// Classement d'une saison (`GET /v1/standings`).
    /// - Parameters:
    ///   - season: id de la saison (`currentSeason.id` d'une compétition).
    ///   - group: id d'une poule, pour ne lire qu'elle.
    ///   - split: général, à domicile ou à l'extérieur.
    /// - Throws: `IdalgoError`, ou `CancellationError` si la tâche est annulée.
    public func standings(
        season: String,
        group: String? = nil,
        split: StandingSplit = .overall
    ) async throws -> Standings {
        var query = ["season": season]
        query["group"] = group
        if split != .overall { query["split"] = split.rawValue }
        return try await get("/v1/standings", query: query)
    }

    // MARK: - Requêtes

    /// Lit `data` de l'enveloppe `{ data, meta, links }` d'une route.
    func get<T: Decodable & Sendable>(_ path: String, query: [String: String]) async throws -> T {
        try decode(Envelope<T>.self, from: await body(for: url(path, query: query), live: false)).data
    }

    /// Lit une page d'une route de liste : `data` et `meta.cursor`.
    func getList<T: Decodable & Sendable>(_ path: String, query: [String: String]) async throws -> ListEnvelope<T> {
        try decode(ListEnvelope<T>.self, from: await body(for: url(path, query: query), live: false))
    }

    /// Lit une route live : `data` et `meta.pollAfter`. Le réseau est toujours interrogé (avec
    /// `If-None-Match`) : `/live` répond `max-age=60`, alors que `pollAfter` peut être plus court.
    func getLive<T: Decodable & Sendable>(_ path: String, query: [String: String]) async throws -> LiveUpdate<T> {
        let envelope = try decode(LiveEnvelope<T>.self, from: await body(for: url(path, query: query), live: true))
        return LiveUpdate(data: envelope.data, pollAfter: envelope.meta.pollAfter)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw IdalgoError.decoding(message: String(describing: error))
        }
    }

    /// Adresse complète, paramètres triés (comme `links.self`) pour partager les entrées du CDN.
    func url(_ path: String, query: [String: String]) throws -> URL {
        let endpoint = configuration.baseURL.appendingPathComponent(path)
        var items = query
        items["lang"] = configuration.lang
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw IdalgoError.network(code: .badURL, message: "Adresse invalide : \(endpoint)")
        }
        components.queryItems = items.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else {
            throw IdalgoError.network(code: .badURL, message: "Adresse invalide : \(endpoint)")
        }
        return url
    }

    /// Corps de la réponse : depuis le cache s'il est frais (sauf en direct), sinon revalidé ou
    /// relu. Deux lectures identiques en cours partagent le même appel.
    private func body(for url: URL, live: Bool) async throws -> Data {
        if !live, let cached = await cache.entry(for: url), cached.isFresh(at: now()) { return cached.data }
        do {
            return try await inFlight.data(for: url) { try await self.fetch(url) }
        } catch {
            throw IdalgoError.wrapping(error)
        }
    }

    /// Lit `url` sur le réseau, avec l'`ETag` d'une réponse déjà gardée, et range la réponse.
    private func fetch(_ url: URL) async throws -> Data {
        let cached = await cache.entry(for: url)
        let (data, response) = try await send(request(for: url, etag: cached?.etag))
        let cacheControl = CacheControl(header: response.value(forHTTPHeaderField: "Cache-Control"))
        switch response.statusCode {
        case 304:
            guard let cached else { throw IdalgoError.api(status: 304, code: nil, detail: nil) }
            await cache.store(cached.data, etag: cached.etag, cacheControl: cacheControl, for: url, at: now())
            return cached.data
        case 200..<300:
            let etag = response.value(forHTTPHeaderField: "ETag")
            await cache.store(data, etag: etag, cacheControl: cacheControl, for: url, at: now())
            return data
        default:
            throw Problem.error(from: data, status: response.statusCode, contentType: response.value(forHTTPHeaderField: "Content-Type"))
        }
    }

    /// La requête : JSON, app et SDK identifiés, clé publique en `Bearer`. Le délai est celui du
    /// transport.
    func request(for url: URL, etag: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(identity.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(identity.bundleIdentifier, forHTTPHeaderField: "X-Idalgo-App")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty, !IdalgoConfiguration.isSecretKey(apiKey) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return request
    }

    /// Envoie la requête, en retentant les erreurs réseau, 5xx et 429 selon `retryPolicy` (le
    /// délai d'un 429 ou d'un 503 est son `Retry-After`).
    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var retry = 0
        while true {
            do {
                let (data, response) = try await transport.send(request)
                if retry < retryPolicy.maxRetries, RetryPolicy.isRetryable(status: response.statusCode) {
                    try await wait(retryPolicy.delay(beforeRetry: retry, after: response, now: now()))
                    retry += 1
                    continue
                }
                return (data, response)
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch is CancellationError {
                throw CancellationError()
            } catch where retry < retryPolicy.maxRetries && !(error is IdalgoError) {
                try await wait(retryPolicy.delay(beforeRetry: retry))
                retry += 1
            } catch {
                throw IdalgoError.wrapping(error)
            }
        }
    }

    private func wait(_ delay: Duration) async throws {
        try Task.checkCancellation()
        try await sleep(delay)
    }
}
