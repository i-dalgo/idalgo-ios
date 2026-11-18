import Foundation
import Testing
@testable import IdalgoCore

/// Lectures live rejouées dans l'ordre par le test.
final class LiveScript: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [Result<LiveUpdate<Int>, IdalgoError>]
    private(set) var reads = 0

    init(_ replies: [Result<LiveUpdate<Int>, IdalgoError>]) {
        self.replies = replies
    }

    func next() throws -> LiveUpdate<Int> {
        try lock.withLock {
            reads += 1
            return try replies.removeFirst().get()
        }
    }
}

/// Valeurs reçues par `onUpdate`.
final class Received: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [Int] = []
    func append(_ value: Int) { lock.withLock { values.append(value) } }
}

@Suite("Direct : quand relire, à quel rythme")
struct LiveTests {
    static let kickoff = Date(timeIntervalSince1970: 1_800_000_000)

    static func delay(_ status: ContestStatus, minutesFromKickoff: Double, startsAt: Date? = kickoff) -> TimeInterval? {
        LiveSchedule.startDelay(status: status, startsAt: startsAt, now: kickoff.addingTimeInterval(minutesFromKickoff * 60))
    }

    @Test("relecture dès 90 min avant le coup d'envoi, tout de suite pendant le match")
    func startDelay() {
        #expect(Self.delay(.scheduled, minutesFromKickoff: -120) == TimeInterval(30 * 60))
        #expect(Self.delay(.scheduled, minutesFromKickoff: -90) == 0)
        #expect(Self.delay(.scheduled, minutesFromKickoff: -10) == 0)
        #expect(Self.delay(.live, minutesFromKickoff: -500) == 0)
    }

    @Test("rien à relire : terminé, reporté, sans heure, bloqué, trop loin")
    func noDelay() {
        #expect(Self.delay(.finished, minutesFromKickoff: 0) == nil)
        #expect(Self.delay(.postponed, minutesFromKickoff: -60) == nil)
        #expect(Self.delay(.scheduled, minutesFromKickoff: 0, startsAt: nil) == nil)
        #expect(Self.delay(.scheduled, minutesFromKickoff: 6 * 60 + 1) == nil)
        #expect(Self.delay(.scheduled, minutesFromKickoff: -(26 * 60)) == nil)
        #expect(Self.delay(ContestStatus(rawValue: "suspended"), minutesFromKickoff: 0) == nil)
    }

    @Test("le jour se relit au plus proche de ses matchs")
    func firstDelay() throws {
        let day = try Fixtures.scoreCenter("score-center-scheduled")
        let now = ScoreCenterTests.instant("2026-11-17T14:00:00Z")
        // Coup d'envoi 20:45 UTC : relecture à 19:15 UTC, dans 5 h 15.
        #expect(LiveSchedule.firstStartDelay(for: day.allContests, now: now) == TimeInterval(5 * 3600 + 15 * 60))
        let finished = try Fixtures.scoreCenter("score-center-finished")
        #expect(LiveSchedule.firstStartDelay(for: finished.allContests, now: now) == nil)
    }

    @Test("attend le délai, puis relit au rythme de pollAfter jusqu'à nil, en reportant chaque lecture")
    func cadence() async throws {
        let sleeps = SleepRecorder()
        let script = LiveScript([
            .success(LiveUpdate(data: 1, pollAfter: 15)),
            .success(LiveUpdate(data: 2, pollAfter: 60)),
            .success(LiveUpdate(data: 3, pollAfter: nil)),
        ])
        let received = Received()
        try await LiveStream.follow(
            0, after: .seconds(120), sleep: { sleeps.record($0) }, fetchLive: { _ in try script.next() }, merge: { $0 + $1 }
        ) { received.append($0) }
        #expect(sleeps.delays == [.seconds(120), .seconds(15), .seconds(60)])
        #expect(received.values == [1, 3, 6])
    }

    @Test("erreur passagère : nouvel essai dans 30 s ; erreur permanente : levée")
    func errors() async {
        let sleeps = SleepRecorder()
        let script = LiveScript([
            .failure(.api(status: 503, code: nil, detail: nil)),
            .success(LiveUpdate(data: 1, pollAfter: 15)),
            .failure(.api(status: 404, code: nil, detail: nil)),
        ])
        await #expect(throws: IdalgoError.api(status: 404, code: nil, detail: nil)) {
            try await LiveStream.follow(
                0, after: .zero, sleep: { sleeps.record($0) }, fetchLive: { _ in try script.next() }, merge: { $0 + $1 }
            ) { _ in }
        }
        #expect(sleeps.delays == [.zero, .seconds(30), .seconds(15)])
        #expect(script.reads == 3)
    }
}
