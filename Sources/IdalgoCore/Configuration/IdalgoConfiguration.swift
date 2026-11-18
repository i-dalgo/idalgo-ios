import Foundation

/// Réglages du SDK : clé, adresse de l'API, langue des noms et thème des composants.
public struct IdalgoConfiguration: Sendable, Hashable {
    /// Adresse de l'API iDalgo de production.
    public static let productionBaseURL = URL(string: "https://api.idalgo.live")!

    /// Clé publique `idl_pk_…`, envoyée en `Authorization: Bearer` : sans elle, l'API répond 401.
    /// Une clé secrète `idl_sk_…` (réservée aux serveurs) n'est jamais envoyée.
    public var apiKey: String?
    /// Adresse de l'API, sans barre finale.
    public var baseURL: URL
    /// Langue des noms renvoyés par l'API (`?lang=`).
    public var lang: String
    /// Thème des composants, que chaque vue peut remplacer (`.idalgoTheme(_:)`).
    public var theme: IdalgoTheme

    public init(
        apiKey: String? = nil,
        baseURL: URL = IdalgoConfiguration.productionBaseURL,
        lang: String = "fr",
        theme: IdalgoTheme = .default
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.lang = lang
        self.theme = theme
    }

    /// Préfixe des clés secrètes, réservées aux serveurs.
    static let secretKeyPrefix = "idl_sk_"

    static func isSecretKey(_ key: String) -> Bool {
        key.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(secretKeyPrefix)
    }
}
