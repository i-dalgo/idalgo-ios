import Foundation
import Testing
@testable import IdalgoCore

/// Transport bouchon : rejoue des réponses dans l'ordre et garde les requêtes reçues.
final class StubTransport: HTTPTransport, @unchecked Sendable {
    enum Reply {
        case response(status: Int, body: Data, headers: [String: String] = [:])
        case failure(URLError.Code)
    }

    private let lock = NSLock()
    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) {
        self.replies = replies
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let reply = lock.withLock {
            requests.append(request)
            return replies.removeFirst()
        }
        switch reply {
        case let .response(status, body, headers):
            return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
        case let .failure(code):
            throw URLError(code)
        }
    }
}

/// Horloge réglable à la main.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_000_000)

    var now: Date { lock.withLock { current } }
    func advance(_ seconds: TimeInterval) { lock.withLock { current += seconds } }
}

/// Délais demandés entre deux tentatives.
final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var delays: [Duration] = []
    func record(_ delay: Duration) { lock.withLock { delays.append(delay) } }
}

@Suite("Client HTTP")
struct ClientTests {
    let clock = TestClock()
    let sleeps = SleepRecorder()

    func client(_ transport: StubTransport, apiKey: String? = nil, lang: String = "fr") -> IdalgoClient {
        IdalgoClient(
            configuration: IdalgoConfiguration(apiKey: apiKey, baseURL: URL(string: "https://api.example.test")!, lang: lang),
            transport: transport,
            retryPolicy: .standard,
            now: { [clock] in clock.now },
            sleep: { [sleeps] in sleeps.record($0) }
        )
    }

    static func ok(_ fixture: String = "standings-league-table", headers: [String: String] = [:]) throws -> StubTransport.Reply {
        .response(status: 200, body: try Fixtures.data(fixture), headers: headers)
    }

    @Test("construit l'adresse : paramètres triés, langue, split hors général")
    func url() async throws {
        let transport = StubTransport([try Self.ok("standings-home")])
        _ = try await client(transport, lang: "en").standings(season: "374703", group: "849303", split: .home)
        #expect(transport.requests[0].url?.absoluteString
            == "https://api.example.test/v1/standings?group=849303&lang=en&season=374703&split=home")
    }

    @Test("le split général n'est pas envoyé")
    func overallSplit() async throws {
        let transport = StubTransport([try Self.ok()])
        _ = try await client(transport).standings(season: "374703")
        #expect(transport.requests[0].url?.query == "lang=fr&season=374703")
    }

    @Test("envoie la clé en Bearer, le User-Agent et Accept")
    func headers() async throws {
        let transport = StubTransport([try Self.ok()])
        _ = try await client(transport, apiKey: "idl_pk_test").standings(season: "374703")
        let request = transport.requests[0]
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer idl_pk_test")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == AppIdentity.current.userAgent)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("sans clé, pas d'en-tête Authorization")
    func noKey() async throws {
        let transport = StubTransport([try Self.ok()])
        _ = try await client(transport).standings(season: "374703")
        #expect(transport.requests[0].value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("sert le cache pendant max-age, puis revalide avec l'ETag (304)")
    func etagRevalidation() async throws {
        let cacheHeaders = ["Cache-Control": "public, max-age=300", "ETag": "W/\"abc\""]
        let transport = StubTransport([
            try Self.ok(headers: cacheHeaders),
            .response(status: 304, body: Data(), headers: cacheHeaders),
        ])
        let client = client(transport)
        let first = try await client.standings(season: "374703")
        let cached = try await client.standings(season: "374703")
        #expect(transport.requests.count == 1)
        clock.advance(301)
        let revalidated = try await client.standings(season: "374703")
        #expect(transport.requests.count == 2)
        #expect(transport.requests[1].value(forHTTPHeaderField: "If-None-Match") == "W/\"abc\"")
        #expect(first == cached)
        #expect(first == revalidated)
        // Le 304 a rouvert une fenêtre de fraîcheur.
        _ = try await client.standings(season: "374703")
        #expect(transport.requests.count == 2)
    }

    @Test("no-store : rien n'est gardé")
    func noStore() async throws {
        let transport = StubTransport([
            try Self.ok(headers: ["Cache-Control": "no-store", "ETag": "\"x\""]),
            try Self.ok(),
        ])
        let client = client(transport)
        _ = try await client.standings(season: "374703")
        _ = try await client.standings(season: "374703")
        #expect(transport.requests.count == 2)
        #expect(transport.requests[1].value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test("traduit une erreur problem+json en IdalgoError.api")
    func apiError() async throws {
        let transport = StubTransport([.response(
            status: 404, body: try Fixtures.data("error-not-found"),
            headers: ["Content-Type": "application/problem+json"]
        )])
        await #expect(throws: IdalgoError.api(status: 404, code: "season-not-found", detail: "Saison 999999999 inconnue")) {
            try await client(transport).standings(season: "999999999")
        }
    }

    @Test("un 502 de Cloudflare (HTML ou JSON) ne donne que son statut, jamais son texte", arguments: [
        ("text/html; charset=UTF-8", "<!DOCTYPE html><html><title>502 Bad gateway</title></html>"),
        ("application/json", #"{"title":"Error 502: Bad gateway","status":502,"detail":"The origin web server returned an invalid response."}"#),
    ])
    func upstreamError(contentType: String, body: String) async throws {
        let reply = StubTransport.Reply.response(status: 502, body: Data(body.utf8), headers: ["Content-Type": contentType])
        let transport = StubTransport(Array(repeating: reply, count: 3))
        await #expect(throws: IdalgoError.api(status: 502, code: nil, detail: nil)) {
            try await client(transport).matchSheet(contest: "54776403")
        }
        #expect(IdalgoError.api(status: 502, code: nil, detail: nil).isRetryable)
    }

    @Test("retente un 503 puis réussit, avec 300 ms puis 900 ms d'attente")
    func retryServerError() async throws {
        let transport = StubTransport([
            .response(status: 503, body: Data()),
            .failure(.timedOut),
            try Self.ok(),
        ])
        _ = try await client(transport).standings(season: "374703")
        #expect(transport.requests.count == 3)
        #expect(sleeps.delays == [.milliseconds(300), .milliseconds(900)])
    }

    @Test("abandonne après deux nouvelles tentatives : erreur réseau")
    func networkError() async throws {
        let transport = StubTransport([.failure(.notConnectedToInternet), .failure(.notConnectedToInternet), .failure(.notConnectedToInternet)])
        await #expect {
            try await client(transport).standings(season: "374703")
        } throws: { error in
            guard case .network = error as? IdalgoError else { return false }
            return true
        }
        #expect(transport.requests.count == 3)
    }

    @Test("429 persistant : erreur de l'API après les tentatives")
    func tooManyRequests() async throws {
        let transport = StubTransport(Array(repeating: .response(status: 429, body: Data()), count: 3))
        await #expect(throws: IdalgoError.api(status: 429, code: nil, detail: nil)) {
            try await client(transport).standings(season: "374703")
        }
    }

    @Test("une erreur 4xx n'est pas retentée")
    func noRetryOnClientError() async throws {
        let transport = StubTransport([.response(status: 400, body: Data("{}".utf8))])
        await #expect(throws: IdalgoError.self) { try await client(transport).standings(season: "x") }
        #expect(transport.requests.count == 1)
    }

    @Test("une réponse hors contrat donne IdalgoError.decoding")
    func decodingError() async throws {
        let transport = StubTransport([.response(status: 200, body: Data(#"{"data":{"kind":"league-table"}}"#.utf8))])
        await #expect {
            try await client(transport).standings(season: "374703")
        } throws: { error in
            guard case .decoding = error as? IdalgoError else { return false }
            return true
        }
    }

    @Test("Score Center : sport, jour, compétitions et fuseau, paramètres triés")
    func scoreCenterURL() async throws {
        let transport = StubTransport([try Self.ok("score-center-finished")])
        _ = try await client(transport).scoreCenter(
            sport: "102", date: "2026-11-08", competitions: ["103", "2003"], timeZone: "America/New_York"
        )
        #expect(transport.requests[0].url?.absoluteString
            == "https://api.example.test/modules/score-center/v1?competitions=103,2003&date=2026-11-08&lang=fr&sport=102&timeZone=America/New_York")
    }

    @Test("Score Center : fuseau de l'appareil par défaut, sans jour ni compétitions")
    func scoreCenterDefaults() async throws {
        let transport = StubTransport([try Self.ok("score-center-empty")])
        let day = try await client(transport).scoreCenter(sport: "102")
        let query = try #require(transport.requests[0].url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems)
        #expect(query.map(\.name) == ["lang", "sport", "timeZone"])
        #expect(query.last?.value == TimeZone.current.identifier)
        #expect(day.competitions.isEmpty)
    }

    @Test("Score Center live : route /live et pollAfter")
    func scoreCenterLive() async throws {
        let transport = StubTransport([try Self.ok("score-center-live-inplay")])
        let update = try await client(transport).scoreCenterLive(sport: "102", date: "2026-11-17", timeZone: "Europe/Paris")
        #expect(transport.requests[0].url?.path == "/modules/score-center/v1/live")
        #expect(update.pollAfter == 15)
        #expect(update.data.contests.count == 8)
    }

    @Test("erreurs passagères (réseau, 5xx, 408, 429) à retenter, permanentes (4xx, décodage) non")
    func retryableErrors() {
        #expect(IdalgoError.network(code: .notConnectedToInternet, message: "hors ligne").isRetryable)
        #expect(IdalgoError.api(status: 503, code: nil, detail: nil).isRetryable)
        #expect(IdalgoError.api(status: 408, code: nil, detail: nil).isRetryable)
        #expect(IdalgoError.api(status: 429, code: nil, detail: nil).isRetryable)
        #expect(!IdalgoError.api(status: 404, code: "season-not-found", detail: nil).isRetryable)
        #expect(!IdalgoError.api(status: 400, code: nil, detail: nil).isRetryable)
        #expect(!IdalgoError.decoding(message: "x").isRetryable)
    }
}
