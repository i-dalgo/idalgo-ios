import Foundation

/// Instants du contrat : ISO 8601 en UTC, à la milliseconde (`2026-10-10T13:30:00.000Z`).
enum IdalgoDate {
    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle()

    static func parse(_ value: String) -> Date? {
        (try? withFraction.parse(value)) ?? (try? withoutFraction.parse(value))
    }

    /// Décode un instant facultatif ; une valeur illisible fait échouer le décodage.
    static func decode<Key: CodingKey>(_ container: KeyedDecodingContainer<Key>, _ key: Key) throws -> Date? {
        guard let value = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let date = parse(value) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Instant ISO 8601 illisible : \(value)")
        }
        return date
    }
}
