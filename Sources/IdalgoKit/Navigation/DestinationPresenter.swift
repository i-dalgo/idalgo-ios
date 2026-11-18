import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Comment le SDK ouvre la feuille d'un match touché, quand l'app ne s'en charge pas
/// (`onContestTap`, `.idalgoNavigation`).
public enum IdalgoContestPresentation: Sendable {
    /// Poussée dans la pile de navigation s'il y en a une (`NavigationStack`, ou
    /// `UINavigationController` d'une app UIKit), sinon en feuille modale.
    case automatic
    /// Toujours poussée (la vue doit être dans une `NavigationStack` ou une `UINavigationController`).
    case push
    /// Toujours en feuille modale, avec un bouton « Fermer ».
    case sheet
}

private struct ContestPresentationKey: EnvironmentKey {
    static let defaultValue = IdalgoContestPresentation.automatic
}

extension EnvironmentValues {
    /// Ouverture de la feuille de match par le SDK.
    var idalgoContestPresentation: IdalgoContestPresentation {
        get { self[ContestPresentationKey.self] }
        set { self[ContestPresentationKey.self] = newValue }
    }
}

extension View {
    /// Choisit comment le SDK ouvre la feuille d'un match (par défaut : automatique, poussée dans la
    /// pile de navigation SwiftUI ou dans la `UINavigationController` d'une app UIKit, sinon en
    /// feuille modale).
    public func idalgoContestPresentation(_ presentation: IdalgoContestPresentation) -> some View {
        environment(\.idalgoContestPresentation, presentation)
    }
}

/// Un match à ouvrir.
struct OpenedContest: Identifiable, Hashable {
    let id: String
}

/// Un classement à ouvrir.
struct OpenedStandings: Identifiable, Hashable {
    let season: String
    let highlight: [String]
    var id: String { season }
}

/// La pile de navigation qui contient la vue, vue par la sonde UIKit.
enum NavigationHost: Equatable {
    /// Aucune : la vue n'est dans aucune pile.
    case none
    /// Une `NavigationStack` SwiftUI : `navigationDestination` y pousse la feuille.
    case swiftUIStack
    /// La `UINavigationController` d'une app UIKit, sans `NavigationStack` : `navigationDestination`
    /// n'y ferait rien, la feuille y est poussée dans un `UIHostingController`.
    case uiKit
}

/// Comment la feuille s'ouvre, une fois la pile connue.
enum ContestRoute: Equatable {
    case swiftUIPush
    case uiKitPush
    case sheet

    init(presentation: IdalgoContestPresentation, host: NavigationHost) {
        switch (presentation, host) {
        case (.sheet, _): self = .sheet
        case (_, .uiKit): self = .uiKitPush
        case (.push, _), (.automatic, .swiftUIStack): self = .swiftUIPush
        case (.automatic, .none): self = .sheet
        }
    }
}

/// Ouvre les écrans du SDK pour les vues qu'il enveloppe : la feuille d'un match (poussée ou en
/// feuille modale, selon la présentation choisie et la pile trouvée) et le classement d'une saison
/// (feuille modale). Les écrans ouverts reçoivent le thème, les composants, le routeur, le client
/// et le fuseau.
struct DestinationPresenter: ViewModifier {
    let client: IdalgoClient?
    let timeZone: String?

    @Environment(\.idalgoContestPresentation) private var presentation
    @Environment(\.idalgoTheme) private var theme
    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoComponentsBox) private var components
    @State private var contest: OpenedContest?
    @State private var standings: OpenedStandings?
    @State private var host = NavigationHost.none
    #if canImport(UIKit)
    @State private var navigation = NavigationControllerReference()
    #endif

    func body(content: Content) -> some View {
        let route = ContestRoute(presentation: presentation, host: host)
        let opener = DestinationOpener { destination in
            switch destination {
            case let .contest(id): contest = OpenedContest(id: id)
            case let .standings(season, highlight): standings = OpenedStandings(season: season, highlight: highlight)
            case .team: break
            }
        }
        Group {
            switch route {
            case .swiftUIPush:
                content.navigationDestination(isPresented: Binding(
                    get: { contest != nil },
                    set: { if !$0 { contest = nil } }
                )) {
                    if let contest { destination(contest, modal: false) }
                }
            case .uiKitPush:
                content
            case .sheet:
                content.sheet(item: $contest) { destination($0, modal: true) }
            }
        }
        .environment(\.idalgoOpener, opener)
        .sheet(item: $standings) { opened in
            StandingsSheet(season: opened.season, highlight: opened.highlight, client: client)
                .modifier(Forwarded(theme: theme, navigator: navigator, components: components))
        }
        #if canImport(UIKit)
        .onChange(of: contest) { opened in
            guard let opened, route == .uiKitPush else { return }
            pushInUIKit(opened)
        }
        .background(
            NavigationProbe { host, controller in
                self.host = host
                navigation.controller = controller
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        )
        #endif
    }

    private func destination(_ contest: OpenedContest, modal: Bool) -> some View {
        MatchSheetScreen(contest: contest.id, client: client, timeZone: timeZone, modal: modal)
            .modifier(Forwarded(theme: theme, navigator: navigator, components: components))
    }

    #if canImport(UIKit)
    /// Pousse la feuille dans la `UINavigationController` de l'app UIKit (rien si elle a disparu
    /// entre-temps).
    private func pushInUIKit(_ opened: OpenedContest) {
        contest = nil
        guard let controller = navigation.controller else { return }
        let page = UIHostingController(rootView: destination(opened, modal: false))
        page.title = IdalgoStrings.matchSheet
        page.navigationItem.largeTitleDisplayMode = .never
        controller.pushViewController(page, animated: true)
    }
    #endif
}

/// Thème, routeur et composants de l'app, reposés sur un écran ouvert par le SDK (une feuille
/// modale ou une page poussée n'hérite pas toujours de l'environnement).
struct Forwarded: ViewModifier {
    let theme: IdalgoTheme?
    let navigator: IdalgoNavigator?
    let components: ComponentsBox

    func body(content: Content) -> some View {
        content
            .environment(\.idalgoTheme, theme)
            .environment(\.idalgoNavigator, navigator)
            .environment(\.idalgoComponentsBox, components)
    }
}

/// La feuille d'un match en plein écran : défilante, titrée, avec « Fermer » en feuille modale.
struct MatchSheetScreen: View {
    let contest: String
    let client: IdalgoClient?
    let timeZone: String?
    let modal: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if modal {
            NavigationStack { page }
        } else {
            page
        }
    }

    private var page: some View {
        ScrollView {
            IdalgoMatchSheetView(contest: contest, timeZone: timeZone, client: client)
        }
        .modifier(ScreenBackground())
        .navigationTitle(IdalgoStrings.matchSheet)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if modal {
                ToolbarItem(placement: .confirmationAction) {
                    Button(IdalgoStrings.close) { dismiss() }
                }
            }
        }
    }
}

/// Le classement d'une saison, ouvert par-dessus un composant (bandeau d'un bloc du Score Center,
/// routeur).
struct StandingsSheet: View {
    let season: String
    let highlight: [String]
    let client: IdalgoClient?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                IdalgoStandingsView(season: season, highlight: highlight, client: client)
            }
            .modifier(ScreenBackground())
            .navigationTitle(IdalgoStrings.standings)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(IdalgoStrings.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Fond d'un écran ouvert par le SDK : celui du thème, toujours opaque.
struct ScreenBackground: ViewModifier {
    @Environment(\.idalgoTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let resolved = theme ?? Idalgo.configuration.theme
        let mode = resolved.paletteMode(system: colorScheme == .dark ? .dark : .light)
        content.background(ResolvedTheme.cached(resolved, mode: mode).background.ignoresSafeArea())
    }
}

#if canImport(UIKit)
/// La `UINavigationController` de la sonde, gardée sans la retenir.
@MainActor
final class NavigationControllerReference {
    weak var controller: UINavigationController?
}

/// Sonde UIKit : la vue est-elle dans une pile de navigation, et laquelle ?
private struct NavigationProbe: UIViewControllerRepresentable {
    let onResolve: @MainActor (NavigationHost, UINavigationController?) -> Void

    func makeUIViewController(context: Context) -> ProbeController {
        ProbeController(onResolve: onResolve)
    }

    func updateUIViewController(_ controller: ProbeController, context: Context) {}

    final class ProbeController: UIViewController {
        let onResolve: @MainActor (NavigationHost, UINavigationController?) -> Void

        init(onResolve: @escaping @MainActor (NavigationHost, UINavigationController?) -> Void) {
            self.onResolve = onResolve
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let controller = navigationController
            onResolve(NavigationHost(controller), controller)
        }
    }
}

extension NavigationHost {
    /// La pile d'après la `UINavigationController` trouvée : celle d'une `NavigationStack` est une
    /// classe privée de SwiftUI ; toute autre (UIKit, ou sous-classe de l'app) est celle d'une app
    /// UIKit.
    init(_ controller: UINavigationController?) {
        guard let controller else {
            self = .none
            return
        }
        self = Self.isSwiftUIManaged(type(of: controller)) ? .swiftUIStack : .uiKit
    }

    static func isSwiftUIManaged(_ type: AnyClass) -> Bool {
        let bundle = Bundle(for: type).bundleIdentifier ?? ""
        return bundle.hasPrefix("com.apple.SwiftUI") || NSStringFromClass(type).contains("SwiftUI")
    }
}
#endif
