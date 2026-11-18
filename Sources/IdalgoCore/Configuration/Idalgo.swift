import Foundation
import os

/// Point d'entrée du SDK : une configuration globale et le client partagé qui en découle.
///
/// ```swift
/// Idalgo.configure(IdalgoConfiguration(apiKey: "idl_pk_…"))
/// let standings = try await Idalgo.client.standings(season: "374703")
/// ```
public enum Idalgo {
    /// Version du SDK, envoyée dans le `User-Agent`. La CI la compare à `mobile/VERSION`
    /// (`mobile/scripts/check-version.sh`).
    public static let version = "0.9.0"

    private struct State: Sendable {
        var configuration = IdalgoConfiguration()
        var client: IdalgoClient?
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    static let logger = Logger(subsystem: "live.idalgo.sdk", category: "IdalgoKit")

    /// Remplace la configuration globale ; le client partagé est recréé (cache mémoire compris),
    /// sur la même session réseau.
    ///
    /// Une clé secrète `idl_sk_…` est refusée : elle n'est jamais envoyée, une erreur est
    /// journalisée, et une build de debug s'arrête sur une assertion.
    public static func configure(_ configuration: IdalgoConfiguration) {
        let configuration = withoutSecretKey(configuration)
        state.withLock { $0 = State(configuration: configuration) }
    }

    /// Configuration globale courante (valeurs par défaut tant que `configure` n'a pas été appelé).
    public static var configuration: IdalgoConfiguration {
        state.withLock { $0.configuration }
    }

    /// Client partagé, construit sur la configuration globale.
    public static var client: IdalgoClient {
        state.withLock { state in
            if let client = state.client { return client }
            let client = IdalgoClient(configuration: state.configuration)
            state.client = client
            return client
        }
    }

    // MARK: - Clé secrète

    /// Signalement d'une clé secrète : journal, puis assertion en debug. Remplacé par les tests.
    private static let misuseReporter = OSAllocatedUnfairLock<@Sendable (String) -> Void>(initialState: { message in
        logger.error("\(message, privacy: .public)")
        assertionFailure(message)
    })

    /// Remplace le signalement d'une clé secrète le temps de `body` (tests).
    static func withMisuseReporter<T>(_ reporter: @escaping @Sendable (String) -> Void, _ body: () throws -> T) rethrows -> T {
        let previous = misuseReporter.withLock { current in
            defer { current = reporter }
            return current
        }
        defer { misuseReporter.withLock { $0 = previous } }
        return try body()
    }

    /// La configuration sans sa clé si c'est une clé secrète, signalée.
    static func withoutSecretKey(_ configuration: IdalgoConfiguration) -> IdalgoConfiguration {
        guard let key = configuration.apiKey, IdalgoConfiguration.isSecretKey(key) else { return configuration }
        let report = misuseReporter.withLock { $0 }
        report(
            "IdalgoKit : clé secrète (idl_sk_…) refusée. Elle ne doit jamais être embarquée dans une app ; "
                + "utilisez votre clé publique idl_pk_…. Les requêtes partent sans clé."
        )
        var configuration = configuration
        configuration.apiKey = nil
        return configuration
    }
}
