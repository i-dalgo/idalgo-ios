import Foundation

/// Erreurs du SDK : réponse d'erreur de l'API, réseau injoignable, ou réponse illisible. Le client
/// ne lève rien d'autre, hormis `CancellationError` quand la tâche qui l'appelle est annulée.
public enum IdalgoError: Error, Sendable, Hashable {
    /// L'API a répondu une erreur (`application/problem+json`) : statut HTTP, code stable
    /// (`season-not-found`…) et détail lisible, quand elle les donne.
    case api(status: Int, code: Code?, detail: String?)
    /// Le réseau a échoué (hors ligne, délai dépassé, TLS…), après les nouvelles tentatives :
    /// le code `URLError` quand l'échec vient d'`URLSession`, `nil` pour un transport maison.
    case network(code: URLError.Code?, message: String)
    /// La réponse ne suit pas le contrat attendu.
    case decoding(message: String)

    /// Code stable d'une erreur de l'API (`season-not-found`…). Liste ouverte : un code inconnu
    /// de cette version du SDK se lit tel quel.
    public struct Code: RawRepresentable, Hashable, Sendable, Codable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            rawValue = value
        }

        public init(from decoder: any Decoder) throws {
            rawValue = try decoder.singleValueContainer().decode(String.self)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        /// Paramètre absent ou invalide (curseur, date…).
        public static let invalidRequest = Code(rawValue: "invalid-request")
        /// Route ou ressource inconnue.
        public static let notFound = Code(rawValue: "not-found")
        public static let contestNotFound = Code(rawValue: "contest-not-found")
        public static let seasonNotFound = Code(rawValue: "season-not-found")
        public static let teamNotFound = Code(rawValue: "team-not-found")
        public static let personNotFound = Code(rawValue: "person-not-found")
        /// Erreur inattendue du serveur.
        public static let internalError = Code(rawValue: "internal-error")
    }
}

extension IdalgoError {
    /// Une nouvelle tentative peut-elle réussir ? Oui pour le réseau, les 5xx, 408 et 429 ; non
    /// pour les autres erreurs de l'API (4xx) et une réponse hors contrat, qui se répéteraient.
    public var isRetryable: Bool {
        switch self {
        case .network: true
        case let .api(status, _, _): status >= 500 || status == 408 || status == 429
        case .decoding: false
        }
    }

    /// Toute erreur levée sous le client, ramenée à `IdalgoError` ; `CancellationError` (et
    /// `URLError.cancelled`) restent une annulation.
    static func wrapping(_ error: any Error) -> any Error {
        switch error {
        case let error as IdalgoError: error
        case is CancellationError: error
        case let error as URLError where error.code == .cancelled: CancellationError()
        case let error as URLError: IdalgoError.network(code: error.code, message: error.localizedDescription)
        default: IdalgoError.network(code: nil, message: error.localizedDescription)
        }
    }
}

extension IdalgoError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .api(status, code, detail): detail ?? code?.rawValue ?? "HTTP \(status)"
        case let .network(_, message), let .decoding(message): message
        }
    }
}

/// Corps d'une erreur de l'API (RFC 9457) : `{ type, title, status, code, detail }`, servi en
/// `application/problem+json`. Une autre réponse d'erreur (page HTML ou JSON d'un intermédiaire,
/// comme le 502 de Cloudflare) ne donne que son statut : son texte n'est jamais montré au lecteur.
struct Problem: Decodable {
    static let mediaType = "application/problem+json"

    let status: Int?
    let code: IdalgoError.Code?
    let detail: String?
    let title: String?

    static func error(from data: Data, status: Int, contentType: String?) -> IdalgoError {
        guard contentType?.lowercased().hasPrefix(mediaType) == true,
              let problem = try? JSONDecoder().decode(Problem.self, from: data)
        else { return .api(status: status, code: nil, detail: nil) }
        return .api(status: problem.status ?? status, code: problem.code, detail: problem.detail ?? problem.title)
    }
}
