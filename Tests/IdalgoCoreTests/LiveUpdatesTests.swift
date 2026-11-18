import Foundation
import Testing
@testable import IdalgoCore

/// Les flux publics `scoreCenterUpdates` / `matchSheetUpdates`, sur un transport bouchon et une
/// horloge réglée.
@Suite("Flux du direct")
struct LiveUpdatesTests {
    let sleeps = SleepRecorder()

    /// Client à l'horloge fixe ; ses attentes sont notées sans attendre, et ses flux gardent chaque
    /// document (le lecteur du test peut prendre du retard sur ces attentes instantanées).
    func client(_ transport: StubTransport, now: String) -> IdalgoClient {
        let date = IdalgoDate.parse(now)!
        return IdalgoClient(
            configuration: IdalgoConfiguration(baseURL: URL(string: "https://api.example.test")!),
            transport: transport,
            retryPolicy: .standard,
            liveBuffering: .all,
            now: { date },
            sleep: { [sleeps] in sleeps.record($0) }
        )
    }

    static func ok(_ body: Data) -> StubTransport.Reply {
        .response(status: 200, body: body, headers: ["Content-Type": "application/json"])
    }

    /// Une réponse live enregistrée, `pollAfter` remplacé.
    static func live(_ fixture: String, pollAfter: Int?) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: Fixtures.data(fixture)) as! [String: Any]
        var meta = object["meta"] as! [String: Any]
        meta["pollAfter"] = pollAfter ?? NSNull()
        object["meta"] = meta
        return try JSONSerialization.data(withJSONObject: object)
    }

    /// La feuille terminée d'Arsenal – Leeds, son en-tête, ses actions et ses compositions pris au
    /// direct de la 67e : un match en cours.
    static func liveMatchSheet() throws -> Data {
        var sheet = try JSONSerialization.jsonObject(with: Fixtures.data("match-sheet-finished")) as! [String: Any]
        let live = try JSONSerialization.jsonObject(with: Fixtures.data("match-sheet-live-inplay")) as! [String: Any]
        var data = sheet["data"] as! [String: Any]
        let liveData = live["data"] as! [String: Any]
        for key in ["contest", "actions", "lineups"] { data[key] = liveData[key] }
        sheet["data"] = data
        return try JSONSerialization.data(withJSONObject: sheet)
    }

    static func collect<T>(_ stream: AsyncThrowingStream<T, Error>) async throws -> [T] {
        var values: [T] = []
        for try await value in stream { values.append(value) }
        return values
    }

    @Test("Score Center : le jour, puis le direct reporté dès 90 min avant le coup d'envoi, jusqu'à pollAfter nul")
    func scoreCenterCadence() async throws {
        let transport = StubTransport([
            Self.ok(try Fixtures.data("score-center-scheduled")),
            Self.ok(try Self.live("score-center-live-inplay", pollAfter: 15)),
            Self.ok(try Self.live("score-center-live-inplay", pollAfter: nil)),
        ])
        // 14:00 UTC, coups d'envoi à 20:45 : direct à 19:15, dans 5 h 15.
        let days = try await Self.collect(client(transport, now: "2026-11-17T14:00:00Z").scoreCenterUpdates(sport: "102"))
        #expect(days.count == 3)
        #expect(days[0].allContests.allSatisfy { $0.status == .scheduled })
        #expect(days[1].allContests.filter { $0.status == .live }.count == 2)
        #expect(sleeps.delays == [.seconds(5 * 3600 + 15 * 60), .seconds(15)])
        let live = try #require(transport.requests.last?.url)
        #expect(live.path == "/modules/score-center/v1/live")
        // Le direct relit le jour lu et son fuseau, même sans jour demandé.
        #expect(live.query?.contains("date=2026-11-17") == true)
        #expect(live.query?.contains("timeZone=Europe/Paris") == true)
    }

    @Test("jour terminé : une seule lecture, le flux se termine aussitôt")
    func finishedDay() async throws {
        let transport = StubTransport([Self.ok(try Fixtures.data("score-center-finished"))])
        let days = try await Self.collect(client(transport, now: "2026-11-17T14:00:00Z").scoreCenterUpdates(sport: "102", date: "2026-11-08"))
        #expect(days.count == 1)
        #expect(transport.requests.count == 1)
        #expect(sleeps.delays.isEmpty)
    }

    @Test("une erreur passagère pendant le direct garde le flux ouvert : nouvel essai 30 s plus tard")
    func survivesRetryableError() async throws {
        let unavailable = StubTransport.Reply.response(status: 503, body: Data(), headers: [:])
        let transport = StubTransport([
            Self.ok(try Self.liveMatchSheet()),
            unavailable, unavailable, unavailable,
            Self.ok(try Self.live("match-sheet-live-inplay", pollAfter: nil)),
        ])
        let sheets = try await Self.collect(client(transport, now: "2026-11-17T14:00:00Z").matchSheetUpdates(contest: "54732603"))
        #expect(sheets.count == 2)
        #expect(sheets.allSatisfy { $0.contest.status == .live })
        // Match en cours : direct tout de suite ; deux nouvelles tentatives du client, puis 30 s.
        #expect(sleeps.delays == [.zero, .milliseconds(300), .milliseconds(900), .seconds(30)])
    }

    @Test("une erreur permanente pendant le direct termine le flux en échec, après la feuille")
    func endsOnNotFound() async throws {
        let transport = StubTransport([
            Self.ok(try Self.liveMatchSheet()),
            .response(status: 404, body: try Fixtures.data("error-not-found"), headers: ["Content-Type": "application/problem+json"]),
        ])
        var received = 0
        await #expect(throws: IdalgoError.api(status: 404, code: "season-not-found", detail: "Saison 999999999 inconnue")) {
            for try await _ in client(transport, now: "2026-11-17T14:00:00Z").matchSheetUpdates(contest: "54732603") { received += 1 }
        }
        #expect(received == 1)
    }

    @Test("une erreur à la première lecture termine le flux en échec")
    func endsOnFirstLoadError() async throws {
        let transport = StubTransport([.response(status: 400, body: Data(), headers: [:])])
        await #expect(throws: IdalgoError.api(status: 400, code: nil, detail: nil)) {
            try await Self.collect(client(transport, now: "2026-11-17T14:00:00Z").matchSheetUpdates(contest: "1"))
        }
    }

    @Test("match à venir : le direct commence 90 min avant le coup d'envoi")
    func matchSheetWaitsForKickoff() async throws {
        let transport = StubTransport([
            Self.ok(try Fixtures.data("match-sheet-scheduled")),
            Self.ok(try Self.live("match-sheet-live-scheduled", pollAfter: nil)),
        ])
        let sheets = try await Self.collect(client(transport, now: "2026-11-17T18:15:00Z").matchSheetUpdates(contest: "54436503"))
        #expect(sheets.count == 2)
        // Coup d'envoi 20:45 UTC, direct à 19:15 : une heure d'attente.
        #expect(sleeps.delays == [.seconds(3600)])
    }

    @Test("cesser de lire le flux arrête les requêtes")
    func cancellationStopsRequests() async throws {
        let replies = [Self.ok(try Self.liveMatchSheet())]
            + Array(repeating: Self.ok(try Self.live("match-sheet-live-inplay", pollAfter: 15)), count: 10)
        let transport = StubTransport(replies)
        // Attentes réelles : le flux attend 15 s après la première lecture live, et l'annulation l'interrompt.
        let client = IdalgoClient(
            configuration: IdalgoConfiguration(baseURL: URL(string: "https://api.example.test")!),
            transport: transport, retryPolicy: .none, now: { Date() }, sleep: { try await Task.sleep(for: $0) }
        )
        var received = 0
        for try await _ in client.matchSheetUpdates(contest: "54732603") {
            received += 1
            if received == 2 { break }
        }
        try await Task.sleep(for: .milliseconds(100))
        #expect(transport.requests.count == 2)
    }
}
