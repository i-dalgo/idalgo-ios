import Foundation

/// L'app qui appelle l'API, envoyée avec chaque requête : `X-Idalgo-App` porte son identifiant de
/// bundle, le `User-Agent` la version du SDK, l'app et le système
/// (`IdalgoKit-iOS/0.9.0 (com.media.app; iOS 18.2)`). Sert au suivi de la consommation par app.
struct AppIdentity: Sendable, Hashable {
    /// Identifiant de bundle quand l'app n'en a pas (outil en ligne de commande).
    static let unknownApp = "unknown"

    let bundleIdentifier: String
    let system: String

    static let current = AppIdentity(
        bundleIdentifier: Bundle.main.bundleIdentifier ?? unknownApp,
        system: systemDescription(ProcessInfo.processInfo.operatingSystemVersion)
    )

    var userAgent: String {
        "IdalgoKit-iOS/\(Idalgo.version) (\(bundleIdentifier); \(system))"
    }

    /// « iOS 18.2 », « iOS 18.2.1 » ; le nom du système pour lequel le SDK est compilé.
    static func systemDescription(_ version: OperatingSystemVersion) -> String {
        let number = [version.majorVersion, version.minorVersion]
            .map(String.init)
            .joined(separator: ".") + (version.patchVersion > 0 ? ".\(version.patchVersion)" : "")
        return "\(systemName) \(number)"
    }

    private static var systemName: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #elseif os(tvOS)
        "tvOS"
        #elseif os(watchOS)
        "watchOS"
        #elseif os(visionOS)
        "visionOS"
        #else
        "unknown"
        #endif
    }
}
