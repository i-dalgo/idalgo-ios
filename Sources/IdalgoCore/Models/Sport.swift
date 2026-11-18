/// Code stable d'un sport. Liste ouverte : une valeur inconnue se décode telle quelle.
public struct SportCode: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let football = SportCode(rawValue: "football")
    public static let rugby = SportCode(rawValue: "rugby")
    public static let basketball = SportCode(rawValue: "basketball")
    public static let handball = SportCode(rawValue: "handball")
    public static let volleyball = SportCode(rawValue: "volleyball")
    public static let other = SportCode(rawValue: "other")
}

/// Un sport : `code` pour le rendu, `id` pour filtrer les autres routes.
public struct Sport: Decodable, Sendable, Hashable {
    public let id: String
    public let code: SportCode
    public let name: String?
}
