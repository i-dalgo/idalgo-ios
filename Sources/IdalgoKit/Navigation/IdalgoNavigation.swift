import SwiftUI

/// Où mène un toucher dans un composant iDalgo.
public enum IdalgoDestination: Hashable, Sendable {
    /// Un match : par défaut, le SDK ouvre sa feuille de match.
    case contest(id: String)
    /// Une équipe : le SDK n'a pas d'écran d'équipe, seule l'app peut y répondre.
    case team(id: String)
    /// Le classement d'une saison, ces équipes mises en avant : par défaut, le SDK l'ouvre dans une
    /// feuille.
    case standings(season: String, highlight: [String])
}

/// Réponse de l'app à une destination (`.idalgoNavigation`).
public enum IdalgoNavigationResult: Sendable {
    /// L'app s'en est chargée (écran poussé, onglet changé…) : le SDK ne fait rien.
    case handled
    /// L'app laisse le SDK ouvrir son propre écran (feuille de match, classement) ; rien pour une
    /// équipe.
    case `default`
}

/// Le routeur de l'app, posé par `.idalgoNavigation`.
struct IdalgoNavigator {
    let route: @MainActor (IdalgoDestination) -> IdalgoNavigationResult
}

/// L'ouverture des écrans du SDK, posée par chaque widget et par `.idalgoNavigation` : la feuille
/// d'un match, le classement d'une saison.
struct DestinationOpener {
    let open: @MainActor (IdalgoDestination) -> Void

    /// Le SDK a-t-il un écran pour cette destination ?
    static func canOpen(_ destination: IdalgoDestination) -> Bool {
        if case .team = destination { return false }
        return true
    }
}

private struct NavigatorKey: EnvironmentKey {
    static let defaultValue: IdalgoNavigator? = nil
}

private struct OpenerKey: EnvironmentKey {
    static let defaultValue: DestinationOpener? = nil
}

extension EnvironmentValues {
    var idalgoNavigator: IdalgoNavigator? {
        get { self[NavigatorKey.self] }
        set { self[NavigatorKey.self] = newValue }
    }

    var idalgoOpener: DestinationOpener? {
        get { self[OpenerKey.self] }
        set { self[OpenerKey.self] = newValue }
    }
}

/// Ce qu'il advient d'un toucher : un seul point de décision, testé.
enum NavigationOutcome: Equatable {
    /// Le raccourci du composant (`onContestTap`, `onTeamTap`, `onTap`) l'a reçu.
    case shortcut
    /// Le routeur de l'app s'en est chargé.
    case host
    /// Le SDK ouvre son écran.
    case sdk
    /// Rien : ni raccourci, ni routeur, ni écran du SDK.
    case ignored

    /// Le raccourci d'abord, puis le routeur de l'app ; s'il répond `.default` (ou s'il n'y en a
    /// pas), l'écran du SDK quand il en a un.
    @MainActor
    static func route(
        _ destination: IdalgoDestination,
        shortcut: (() -> Void)?,
        navigator: IdalgoNavigator?,
        opener: DestinationOpener?
    ) -> NavigationOutcome {
        if let shortcut {
            shortcut()
            return .shortcut
        }
        if let navigator, navigator.route(destination) == .handled { return .host }
        guard let opener, DestinationOpener.canOpen(destination) else { return .ignored }
        opener.open(destination)
        return .sdk
    }

    /// Un toucher mènerait-il quelque part ? (sinon la vue n'est pas présentée comme un bouton)
    static func isActionable(
        _ destination: IdalgoDestination,
        hasShortcut: Bool,
        navigator: IdalgoNavigator?,
        opener: DestinationOpener?
    ) -> Bool {
        hasShortcut || navigator != nil || (opener != nil && DestinationOpener.canOpen(destination))
    }
}

/// Lit le routeur et l'ouverture du SDK dans l'environnement, et route un toucher.
struct NavigationContext {
    let navigator: IdalgoNavigator?
    let opener: DestinationOpener?

    @MainActor
    @discardableResult
    func go(_ destination: IdalgoDestination, shortcut: (() -> Void)? = nil) -> NavigationOutcome {
        NavigationOutcome.route(destination, shortcut: shortcut, navigator: navigator, opener: opener)
    }

    func isActionable(_ destination: IdalgoDestination, hasShortcut: Bool) -> Bool {
        NavigationOutcome.isActionable(destination, hasShortcut: hasShortcut, navigator: navigator, opener: opener)
    }
}

extension View {
    /// Décide où mènent les touchers des composants iDalgo de cette vue et de ses enfants : un
    /// match, une équipe, un classement. Renvoyez `.handled` quand l'app s'en charge, `.default`
    /// pour laisser le SDK ouvrir son écran (feuille de match, classement ; rien pour une équipe).
    ///
    /// Les raccourcis `onContestTap` / `onTeamTap` d'un composant passent avant le routeur. Sous ce
    /// modificateur, les briques (`IdalgoContestRow`, `IdalgoContestCard`…) deviennent touchables et
    /// ouvrent les écrans du SDK quand l'app répond `.default`.
    ///
    /// ```swift
    /// ContentView()
    ///     .idalgoNavigation { destination in
    ///         switch destination {
    ///         case let .team(id):
    ///             router.showTeam(id)
    ///             return .handled
    ///         default:
    ///             return .default
    ///         }
    ///     }
    /// ```
    public func idalgoNavigation(
        _ route: @escaping @MainActor (IdalgoDestination) -> IdalgoNavigationResult
    ) -> some View {
        modifier(DestinationPresenter(client: nil, timeZone: nil))
            .environment(\.idalgoNavigator, IdalgoNavigator(route: route))
    }
}
