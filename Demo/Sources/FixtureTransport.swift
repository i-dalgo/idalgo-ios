import Foundation
import IdalgoKit

/// Transport de démonstration, propre à l'app de démo : sert le Score Center, la feuille de match et
/// leurs routes live depuis les réponses enregistrées (`mobile/fixtures`), pour montrer le direct
/// sans attendre un soir de match.
/// - Score Center : coups d'envoi recalés dans l'heure qui vient et jour sur aujourd'hui, pour que
///   le composant relise le direct aussitôt.
/// - Feuille d'Arsenal – Leeds : l'avant-match de la feuille terminée, avec l'en-tête, les actions
///   et les compositions du direct à la 67e ; Danemark – Norvège : sa feuille à venir.
struct FixtureTransport: HTTPTransport {
    static let client = IdalgoClient(transport: FixtureTransport(), retryPolicy: .none)

    /// Jour et coup d'envoi du Score Center enregistré, remplacés à la volée.
    private static let fixtureDay = "2026-11-17"
    private static let fixtureKickoff = "2026-11-17T20:45:00.000Z"
    /// Le match à venir dont la feuille est enregistrée.
    private static let scheduledContest = "54436503"

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        let isLive = url.path.hasSuffix("/live")
        let body: Data = if url.path.contains("/match-sheet/") {
            try Self.matchSheet(contest: Self.query(url, "contest"), live: isLive)
        } else {
            try Self.scoreCenter(live: isLive)
        }
        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json", "Cache-Control": "no-store"]
        )!
        return (body, response)
    }

    private static func scoreCenter(live: Bool) throws -> Data {
        let text = try String(contentsOf: fixture(live ? "score-center-live-inplay" : "score-center-scheduled"), encoding: .utf8)
            .replacingOccurrences(of: fixtureKickoff, with: kickoff())
            .replacingOccurrences(of: fixtureDay, with: today())
        return Data(text.utf8)
    }

    private static func matchSheet(contest: String?, live: Bool) throws -> Data {
        if contest == scheduledContest {
            return try Data(contentsOf: fixture(live ? "match-sheet-live-scheduled" : "match-sheet-scheduled"))
        }
        let inplay = try Data(contentsOf: fixture("match-sheet-live-inplay"))
        if live { return inplay }
        // Feuille terminée dont l'en-tête, les actions et les compositions sont ceux du direct.
        var sheet = try json(fixture("match-sheet-finished"))
        var data = sheet["data"] as? [String: Any] ?? [:]
        let liveData = (try JSONSerialization.jsonObject(with: inplay) as? [String: Any])?["data"] as? [String: Any] ?? [:]
        for key in ["contest", "actions", "lineups"] { data[key] = liveData[key] }
        sheet["data"] = data
        return try JSONSerialization.data(withJSONObject: sheet)
    }

    private static func fixture(_ name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else { throw URLError(.fileDoesNotExist) }
        return url
    }

    private static func json(_ url: URL) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
    }

    private static func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    /// Aujourd'hui (`AAAA-MM-JJ`) dans le fuseau de l'appareil.
    private static func today() -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Coup d'envoi au prochain quart d'heure plus une heure : dans la fenêtre du direct.
    private static func kickoff() -> String {
        let quarter: TimeInterval = 15 * 60
        let start = (Date().timeIntervalSince1970 / quarter).rounded(.up) * quarter + 3600
        return Date(timeIntervalSince1970: start).formatted(.iso8601)
    }
}
