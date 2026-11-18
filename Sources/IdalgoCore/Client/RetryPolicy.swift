import Foundation

/// Nouvelles tentatives sur erreur réseau, réponse 5xx ou 429, avec un délai croissant. Sur un 429
/// ou un 503, le délai est celui de l'en-tête `Retry-After` quand le serveur le donne, plafonné à
/// `maxRetryAfter`.
public struct RetryPolicy: Sendable, Hashable {
    /// Tentatives après la première.
    public var maxRetries: Int
    /// Délai avant la première nouvelle tentative.
    public var initialDelay: Duration
    /// Facteur appliqué au délai à chaque tentative.
    public var multiplier: Int
    /// Attente maximale demandée par un `Retry-After` : au-delà, le serveur est tenu pour
    /// saturé et la tentative a lieu au bout de ce plafond.
    public var maxRetryAfter: Duration

    /// Deux nouvelles tentatives, après 300 ms puis 900 ms (ou le `Retry-After`, 60 s au plus).
    public static let standard = RetryPolicy(maxRetries: 2, initialDelay: .milliseconds(300), multiplier: 3)
    /// Aucune nouvelle tentative.
    public static let none = RetryPolicy(maxRetries: 0, initialDelay: .zero, multiplier: 1)

    public init(maxRetries: Int, initialDelay: Duration, multiplier: Int, maxRetryAfter: Duration = .seconds(60)) {
        self.maxRetries = maxRetries
        self.initialDelay = initialDelay
        self.multiplier = multiplier
        self.maxRetryAfter = maxRetryAfter
    }

    /// Délai avant la tentative `retry` (0 pour la première nouvelle tentative).
    func delay(beforeRetry retry: Int) -> Duration {
        (0..<retry).reduce(initialDelay) { delay, _ in delay * multiplier }
    }

    /// Délai avant la tentative `retry` après une réponse : son `Retry-After` (429, 503) s'il se
    /// lit, plafonné, sinon le délai croissant.
    func delay(beforeRetry retry: Int, after response: HTTPURLResponse, now: Date) -> Duration {
        guard response.statusCode == 429 || response.statusCode == 503,
              let seconds = Self.retryAfter(response.value(forHTTPHeaderField: "Retry-After"), now: now)
        else { return delay(beforeRetry: retry) }
        return min(.milliseconds(Int64((seconds * 1000).rounded())), maxRetryAfter)
    }

    static func isRetryable(status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    /// Secondes demandées par un `Retry-After` (RFC 9110) : un nombre de secondes, ou une date
    /// HTTP (`Wed, 21 Oct 2026 07:28:00 GMT`) ; 0 pour une date passée, `nil` s'il ne se lit pas.
    static func retryAfter(_ value: String?, now: Date) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = Int(value) { return seconds >= 0 ? TimeInterval(seconds) : nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(date.timeIntervalSince(now), 0)
    }
}
