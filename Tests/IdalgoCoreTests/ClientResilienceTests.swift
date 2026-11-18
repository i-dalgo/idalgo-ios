import Foundation
import Testing
@testable import IdalgoCore

/// Transport qui retient chaque requête jusqu'à `release()` : des lectures restent en cours le
/// temps de vérifier qu'elles partagent l'appel. Une requête annulée lève `CancellationError`.
final class GatedTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private(set) var count = 0
    let body: Data

    init(body: Data) {
        self.body = body
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { count += 1 }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let resume = lock.withLock {
                    if released { return true }
                    waiting.append(continuation)
                    return false
                }
                if resume { continuation.resume() }
            }
        } onCancel: {
            release()
        }
        try Task.checkCancellation()
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: [:])!)
    }

    func release() {
        let continuations = lock.withLock {
            released = true
            defer { waiting = [] }
            return waiting
        }
        continuations.forEach { $0.resume() }
    }
}

/// Transport qui lève une erreur maison, hors `URLError`.
struct FailingTransport: HTTPTransport {
    struct Failure: Error {}

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        throw Failure()
    }
}

/// Valeurs reçues d'un autre fil.
final class Recorder<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [T] = []
    var values: [T] { lock.withLock { storage } }
    func append(_ value: T) { lock.withLock { storage.append(value) } }
}

@Suite("Client : direct, Retry-After, requêtes partagées, identification")
struct ClientResilienceTests {
    let clock = TestClock()
    let sleeps = SleepRecorder()

    func client(
        _ transport: any HTTPTransport,
        apiKey: String? = nil,
        identity: AppIdentity = .current
    ) -> IdalgoClient {
        IdalgoClient(
            configuration: IdalgoConfiguration(apiKey: apiKey, baseURL: URL(string: "https://api.example.test")!),
            transport: transport,
            retryPolicy: .standard,
            identity: identity,
            now: { [clock] in clock.now },
            sleep: { [sleeps] in sleeps.record($0) }
        )
    }

    // MARK: Direct

    @Test("une route live interroge toujours le réseau, malgré max-age, et revalide avec l'ETag")
    func liveIgnoresFreshness() async throws {
        let headers = ["Cache-Control": "public, max-age=60", "ETag": "\"live-1\""]
        let transport = StubTransport([
            .response(status: 200, body: try Fixtures.data("score-center-live-inplay"), headers: headers),
            .response(status: 304, body: Data(), headers: headers),
        ])
        let client = client(transport)
        let first = try await client.scoreCenterLive(sport: "102", date: "2026-11-17", timeZone: "Europe/Paris")
        clock.advance(15)
        let second = try await client.scoreCenterLive(sport: "102", date: "2026-11-17", timeZone: "Europe/Paris")
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(transport.requests[1].value(forHTTPHeaderField: "If-None-Match") == "\"live-1\"")
        #expect(second.data == first.data)
        #expect(second.pollAfter == 15)
    }

    @Test("une route non live reste servie par le cache pendant max-age")
    func moduleKeepsFreshness() async throws {
        let transport = StubTransport([
            .response(status: 200, body: try Fixtures.data("match-sheet-finished"), headers: ["Cache-Control": "max-age=60"]),
        ])
        let client = client(transport)
        _ = try await client.matchSheet(contest: "54732603")
        _ = try await client.matchSheet(contest: "54732603")
        #expect(transport.requests.count == 1)
    }

    @Test("un 304 sans réponse gardée est une erreur de l'API, pas un plantage")
    func notModifiedWithoutCache() async throws {
        let transport = StubTransport([.response(status: 304, body: Data())])
        await #expect(throws: IdalgoError.api(status: 304, code: nil, detail: nil)) {
            try await client(transport).standings(season: "374703")
        }
    }

    // MARK: Retry-After

    @Test("429 : attend les secondes de Retry-After avant de retenter")
    func retryAfterSeconds() async throws {
        let transport = StubTransport([
            .response(status: 429, body: Data(), headers: ["Retry-After": "5"]),
            .response(status: 200, body: try Fixtures.data("standings-league-table")),
        ])
        _ = try await client(transport).standings(season: "374703")
        #expect(sleeps.delays == [.seconds(5)])
    }

    @Test("503 : Retry-After en date HTTP, comptée depuis l'horloge du client")
    func retryAfterDate() async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        let transport = StubTransport([
            .response(status: 503, body: Data(), headers: ["Retry-After": formatter.string(from: clock.now.addingTimeInterval(12))]),
            .response(status: 200, body: try Fixtures.data("standings-league-table")),
        ])
        _ = try await client(transport).standings(season: "374703")
        #expect(sleeps.delays == [.seconds(12)])
    }

    @Test("Retry-After est plafonné à 60 s")
    func retryAfterCapped() async throws {
        let transport = StubTransport([
            .response(status: 429, body: Data(), headers: ["Retry-After": "3600"]),
            .response(status: 200, body: try Fixtures.data("standings-league-table")),
        ])
        _ = try await client(transport).standings(season: "374703")
        #expect(sleeps.delays == [.seconds(60)])
    }

    @Test("sans Retry-After lisible, ou sur un autre 5xx, le délai croissant s'applique")
    func retryAfterIgnored() async throws {
        let transport = StubTransport([
            .response(status: 429, body: Data(), headers: ["Retry-After": "demain"]),
            .response(status: 500, body: Data(), headers: ["Retry-After": "30"]),
            .response(status: 200, body: try Fixtures.data("standings-league-table")),
        ])
        _ = try await client(transport).standings(season: "374703")
        #expect(sleeps.delays == [.milliseconds(300), .milliseconds(900)])
    }

    @Test("lecture de Retry-After : secondes, date HTTP, date passée, valeur illisible")
    func retryAfterParsing() {
        let now = Date(timeIntervalSince1970: 1_700_000_000) // Tue, 14 Nov 2023 22:13:20 GMT
        #expect(RetryPolicy.retryAfter("7", now: now) == 7)
        #expect(RetryPolicy.retryAfter(" 0 ", now: now) == 0)
        #expect(RetryPolicy.retryAfter("Tue, 14 Nov 2023 22:13:50 GMT", now: now) == 30)
        #expect(RetryPolicy.retryAfter("Tue, 14 Nov 2023 22:00:00 GMT", now: now) == 0)
        #expect(RetryPolicy.retryAfter("-3", now: now) == nil)
        #expect(RetryPolicy.retryAfter("bientôt", now: now) == nil)
        #expect(RetryPolicy.retryAfter(nil, now: now) == nil)
    }

    // MARK: Requêtes partagées

    @Test("deux lectures identiques simultanées partagent un seul appel réseau")
    func inFlightDeduplication() async throws {
        let transport = GatedTransport(body: try Fixtures.data("standings-league-table"))
        let client = client(transport)
        let url = try client.url("/v1/standings", query: ["season": "374703"])
        async let first = client.standings(season: "374703")
        async let second = client.standings(season: "374703")
        while await client.inFlight.waiters(for: url) < 2 { await Task.yield() }
        transport.release()
        let (a, b) = try await (first, second)
        #expect(a == b)
        #expect(transport.count == 1)
        #expect(await client.inFlight.waiters(for: url) == 0)
    }

    @Test("des lectures différentes ne se partagent pas")
    func distinctRequests() async throws {
        let transport = GatedTransport(body: try Fixtures.data("standings-league-table"))
        transport.release()
        let client = client(transport)
        async let first = client.standings(season: "374703")
        async let second = client.standings(season: "374703", split: .home)
        _ = try await (first, second)
        #expect(transport.count == 2)
    }

    @Test("annuler le seul lecteur annule l'appel partagé")
    func cancellationCancelsSharedCall() async throws {
        let transport = GatedTransport(body: try Fixtures.data("standings-league-table"))
        let client = client(transport)
        let url = try client.url("/v1/standings", query: ["season": "374703"])
        let task = Task { try await client.standings(season: "374703") }
        while await client.inFlight.waiters(for: url) < 1 { await Task.yield() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    // MARK: Erreurs

    @Test("une erreur maison du transport devient IdalgoError.network, sans code URLError")
    func customTransportError() async throws {
        await #expect {
            try await client(FailingTransport()).standings(season: "374703")
        } throws: { error in
            guard case let .network(code, _) = error as? IdalgoError else { return false }
            return code == nil
        }
        #expect(sleeps.delays.count == 2)
    }

    @Test("une erreur URLSession garde son code URLError")
    func urlErrorCodeKept() async throws {
        let transport = StubTransport(Array(repeating: .failure(.timedOut), count: 3))
        await #expect(throws: IdalgoError.network(code: .timedOut, message: URLError(.timedOut).localizedDescription)) {
            try await client(transport).standings(season: "374703")
        }
    }

    @Test("le code d'erreur de l'API est un type ouvert")
    func openErrorCode() throws {
        let error = Problem.error(
            from: Data(#"{"status":409,"code":"brand-new-code","detail":"Nouveau"}"#.utf8),
            status: 409,
            contentType: "application/problem+json"
        )
        #expect(error == .api(status: 409, code: IdalgoError.Code(rawValue: "brand-new-code"), detail: "Nouveau"))
        #expect(IdalgoError.Code.seasonNotFound == "season-not-found")
    }

    // MARK: Identification

    @Test("chaque requête porte X-Idalgo-App et un User-Agent SDK / app / système")
    func identification() async throws {
        let transport = StubTransport([.response(status: 200, body: try Fixtures.data("standings-league-table"))])
        let identity = AppIdentity(bundleIdentifier: "com.media.app", system: "iOS 18.2")
        _ = try await client(transport, identity: identity).standings(season: "374703")
        let request = transport.requests[0]
        #expect(request.value(forHTTPHeaderField: "X-Idalgo-App") == "com.media.app")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "IdalgoKit-iOS/\(Idalgo.version) (com.media.app; iOS 18.2)")
    }

    @Test("identité de l'app courante : identifiant de bundle et version du système")
    func currentIdentity() {
        let identity = AppIdentity.current
        #expect(identity.bundleIdentifier == (Bundle.main.bundleIdentifier ?? AppIdentity.unknownApp))
        #expect(identity.userAgent.hasPrefix("IdalgoKit-iOS/\(Idalgo.version) ("))
        #expect(AppIdentity.systemDescription(OperatingSystemVersion(majorVersion: 18, minorVersion: 2, patchVersion: 0)).hasSuffix(" 18.2"))
        #expect(AppIdentity.systemDescription(OperatingSystemVersion(majorVersion: 17, minorVersion: 5, patchVersion: 1)).hasSuffix(" 17.5.1"))
    }

    @Test("la version du SDK suit mobile/VERSION")
    func versionMatchesFile() throws {
        let file = Fixtures.directory.deletingLastPathComponent().appendingPathComponent("VERSION")
        // Hors du monorepo (miroir public), le fichier n'existe pas : la CI du monorepo le vérifie.
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return }
        #expect(Idalgo.version == text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: Transport

    @Test("le délai du transport s'applique à chaque requête, sans être remplacé par celui du client")
    func transportTimeout() throws {
        let transport = URLSessionTransport(timeout: 3)
        let client = IdalgoClient(configuration: IdalgoConfiguration(), transport: transport)
        let request = client.request(for: try client.url("/v1/standings", query: [:]), etag: nil)
        #expect(transport.prepared(request).timeoutInterval == 3)
        #expect(URLSessionTransport.shared.prepared(request).timeoutInterval == URLSessionTransport.timeout)
    }

    @Test("les clients créés sans transport partagent la session du SDK")
    func sharedSession() {
        let first = IdalgoClient(configuration: IdalgoConfiguration())
        let second = IdalgoClient(configuration: IdalgoConfiguration(lang: "en"))
        let sessions = [first, second].compactMap { ($0.transport as? URLSessionTransport)?.session }
        #expect(sessions.count == 2)
        #expect(sessions[0] === sessions[1])
        #expect(sessions[0] === URLSessionTransport.shared.session)
    }
}

/// Ce qui touche à la configuration globale `Idalgo` : un test à la fois.
@Suite("Configuration globale", .serialized)
struct GlobalConfigurationTests {
    @Test("configure() remplace le client partagé, sur la même session réseau")
    func configureReplacesClient() {
        let before = Idalgo.client
        Idalgo.configure(IdalgoConfiguration(lang: "en"))
        #expect(Idalgo.configuration.lang == "en")
        #expect(Idalgo.client !== before)
        #expect(Idalgo.client.configuration.lang == "en")
        let sessions = [before, Idalgo.client].compactMap { ($0.transport as? URLSessionTransport)?.session }
        #expect(sessions.count == 2)
        #expect(sessions[0] === sessions[1])
        Idalgo.configure(IdalgoConfiguration())
    }

    @Test("configure() refuse une clé secrète : signalée, jamais gardée")
    func secretKeyRefused() {
        let messages = Recorder<String>()
        Idalgo.withMisuseReporter({ messages.append($0) }) {
            Idalgo.configure(IdalgoConfiguration(apiKey: "idl_sk_0123456789"))
        }
        #expect(Idalgo.configuration.apiKey == nil)
        #expect(Idalgo.client.configuration.apiKey == nil)
        #expect(messages.values.count == 1)
        #expect(messages.values.first?.contains("idl_sk_") == true)
        Idalgo.configure(IdalgoConfiguration())
    }

    @Test("une clé publique est gardée, sans signalement")
    func publicKeyKept() {
        let messages = Recorder<String>()
        Idalgo.withMisuseReporter({ messages.append($0) }) {
            Idalgo.configure(IdalgoConfiguration(apiKey: "idl_pk_0123456789"))
        }
        #expect(Idalgo.configuration.apiKey == "idl_pk_0123456789")
        #expect(messages.values.isEmpty)
        Idalgo.configure(IdalgoConfiguration())
    }

    @Test("un client créé avec une clé secrète ne l'envoie pas")
    func secretKeyNeverSent() async throws {
        let messages = Recorder<String>()
        let transport = StubTransport([.response(status: 200, body: try Fixtures.data("standings-league-table"))])
        let client = Idalgo.withMisuseReporter({ messages.append($0) }) {
            IdalgoClient(
                configuration: IdalgoConfiguration(apiKey: " idl_sk_0123456789", baseURL: URL(string: "https://api.example.test")!),
                transport: transport
            )
        }
        _ = try await client.standings(season: "374703")
        #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == nil)
        #expect(messages.values.count == 1)
    }
}

@Suite("Cache des images")
struct ImageLoaderTests {
    static let logo = URL(string: "https://media.example.test/logo/103.png")!

    @Test("une image lue est gardée : plus d'appel ensuite")
    func caches() async throws {
        let transport = StubTransport([.response(status: 200, body: Data("png".utf8))])
        let loader = ImageLoader<Data>(transport: transport) { $0 }
        #expect(loader.cached(Self.logo) == nil)
        #expect(await loader.image(for: Self.logo) == Data("png".utf8))
        #expect(await loader.image(for: Self.logo) == Data("png".utf8))
        #expect(loader.cached(Self.logo) == Data("png".utf8))
        #expect(transport.requests.count == 1)
    }

    @Test("deux demandes simultanées partagent l'appel")
    func sharesCalls() async throws {
        let transport = GatedTransport(body: Data("png".utf8))
        let loader = ImageLoader<Data>(transport: transport) { $0 }
        async let first = loader.image(for: Self.logo)
        async let second = loader.image(for: Self.logo)
        while await loader.inFlight.waiters(for: Self.logo) < 2 { await Task.yield() }
        transport.release()
        let images = await [first, second]
        #expect(images == [Data("png".utf8), Data("png".utf8)])
        #expect(transport.count == 1)
    }

    @Test("un 404 n'est plus redemandé ; une erreur réseau, si")
    func failures() async throws {
        let missing = URL(string: "https://media.example.test/logo/0.png")!
        let transport = StubTransport([
            .response(status: 404, body: Data()),
            .failure(.notConnectedToInternet),
            .response(status: 200, body: Data("png".utf8)),
        ])
        let loader = ImageLoader<Data>(transport: transport) { $0 }
        #expect(await loader.image(for: missing) == nil)
        #expect(await loader.image(for: missing) == nil)
        #expect(await loader.image(for: Self.logo) == nil)
        #expect(await loader.image(for: Self.logo) == Data("png".utf8))
        #expect(transport.requests.count == 3)
    }
}

@Suite("Flux du direct : lecteur lent")
struct LiveBufferingTests {
    @Test("un lecteur lent ne reçoit que le dernier document")
    func newestOnly() async throws {
        let produced = Recorder<Int>()
        let stream = LiveStream.make(
            now: { Date() },
            sleep: { _ in },
            load: { 0 },
            startDelay: { _, _ in 0 },
            fetchLive: { document in LiveUpdate(data: document + 1, pollAfter: document + 1 < 3 ? 1 : nil) },
            merge: { _, live in
                produced.append(live)
                return live
            }
        )
        // Le lecteur attend que tout soit produit avant de lire.
        while produced.values.count < 3 { try await Task.sleep(for: .milliseconds(5)) }
        try await Task.sleep(for: .milliseconds(20))
        var received: [Int] = []
        for try await document in stream { received.append(document) }
        #expect(received == [3])
    }
}

@Suite("Réponses enregistrées")
struct FixturesLocationTests {
    @Test("Tests/Fixtures (miroir public) s'il existe, sinon mobile/fixtures")
    func resolvesDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("idalgo-fixtures-\(UUID().uuidString)")
        let tests = root.appendingPathComponent("ios/Tests")
        try FileManager.default.createDirectory(at: tests, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(Fixtures.resolveDirectory(tests: tests).standardizedFileURL == root.appendingPathComponent("fixtures").standardizedFileURL)
        try FileManager.default.createDirectory(at: tests.appendingPathComponent("Fixtures"), withIntermediateDirectories: true)
        #expect(Fixtures.resolveDirectory(tests: tests).standardizedFileURL == tests.appendingPathComponent("Fixtures").standardizedFileURL)
    }
}
