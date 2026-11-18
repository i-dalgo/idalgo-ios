#if canImport(UIKit)
import SwiftUI
import UIKit

/// La feuille de match pour une app UIKit : un `UIViewController` à pousser ou présenter, qui fait
/// défiler `IdalgoMatchSheetView`. Changer `contest` ou `theme` met l'écran à jour sans le recréer.
///
/// ```swift
/// let sheet = IdalgoMatchSheetViewController(contest: "54732603")
/// sheet.navigation = { destination in
///     if case let .team(id) = destination { self.showTeam(id); return .handled }
///     return .default
/// }
/// navigationController?.pushViewController(sheet, animated: true)
/// ```
@MainActor
public final class IdalgoMatchSheetViewController: UIViewController {
    /// Id du match ; le changer relit la feuille.
    public var contest: String {
        get { model.contest }
        set { model.contest = newValue }
    }
    /// Thème de l'écran ; `nil` : celui de `Idalgo.configuration`.
    public var theme: IdalgoTheme? { didSet { render() } }
    /// Appelé au toucher d'une équipe, avant `navigation`.
    public var onTeamTap: ((TeamCompetitor) -> Void)? { didSet { render() } }
    /// Routeur de l'écran (comme `.idalgoNavigation`) ; `nil` : le SDK ouvre ses propres écrans.
    public var navigation: (@MainActor (IdalgoDestination) -> IdalgoNavigationResult)? { didSet { render() } }

    private let model: IdalgoMatchSheetModel
    private let tabs: [MatchSheetTab]
    private let timeZone: String?
    private let hosting = UIHostingController<HostedScreen<IdalgoMatchSheetView>?>(rootView: nil)

    /// - Parameters:
    ///   - contest: id du match.
    ///   - initialTab: rubrique ouverte d'emblée.
    ///   - tabs: rubriques proposées, dans cet ordre.
    ///   - timeZone: fuseau IANA des dates et heures ; par défaut, celui de l'appareil.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    public init(
        contest: String,
        initialTab: MatchSheetTab? = nil,
        tabs: [MatchSheetTab] = MatchSheetTab.allCases,
        timeZone: String? = nil,
        client: IdalgoClient? = nil
    ) {
        model = IdalgoMatchSheetModel(contest: contest, initialTab: initialTab, client: client)
        self.tabs = tabs
        self.timeZone = timeZone
        super.init(nibName: nil, bundle: nil)
        title = IdalgoStrings.matchSheet
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func viewDidLoad() {
        super.viewDidLoad()
        embed(hosting, in: self)
        render()
    }

    private func render() {
        hosting.rootView = HostedScreen(
            theme: theme,
            navigation: navigation,
            content: IdalgoMatchSheetView(model: model, tabs: tabs, timeZone: timeZone, onTeamTap: onTeamTap)
        )
    }
}

/// Le classement pour une app UIKit : un `UIViewController` à pousser ou présenter, qui fait
/// défiler `IdalgoStandingsView`. Changer `season`, `competition`, `highlight` ou `theme` met l'écran
/// à jour sans le recréer.
@MainActor
public final class IdalgoStandingsViewController: UIViewController {
    /// Saison affichée (prime sur `competition`).
    public var season: String? { didSet { render() } }
    /// Compétition dont la saison en cours est affichée, quand `season` est `nil`.
    public var competition: String? { didSet { render() } }
    /// Ids des équipes à mettre en avant.
    public var highlight: [String] { didSet { render() } }
    /// Thème de l'écran ; `nil` : celui de `Idalgo.configuration`.
    public var theme: IdalgoTheme? { didSet { render() } }
    /// Appelé au toucher d'une équipe, avant `navigation`.
    public var onTeamTap: ((TeamCompetitor) -> Void)? { didSet { render() } }
    /// Routeur de l'écran (comme `.idalgoNavigation`).
    public var navigation: (@MainActor (IdalgoDestination) -> IdalgoNavigationResult)? { didSet { render() } }

    private let client: IdalgoClient?
    private let hosting = UIHostingController<HostedScreen<IdalgoStandingsView>?>(rootView: nil)

    /// - Parameters:
    ///   - season: id de la saison.
    ///   - highlight: ids des équipes à mettre en avant.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    public init(season: String, highlight: [String] = [], client: IdalgoClient? = nil) {
        self.season = season
        self.highlight = highlight
        self.client = client
        super.init(nibName: nil, bundle: nil)
        title = IdalgoStrings.standings
    }

    /// Le classement de la saison en cours d'une compétition.
    public init(competition: String, highlight: [String] = [], client: IdalgoClient? = nil) {
        self.competition = competition
        self.highlight = highlight
        self.client = client
        super.init(nibName: nil, bundle: nil)
        title = IdalgoStrings.standings
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override public func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        embed(hosting, in: self)
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        let view = if let season {
            IdalgoStandingsView(season: season, highlight: highlight, client: client, onTeamTap: onTeamTap)
        } else {
            IdalgoStandingsView(competition: competition ?? "", highlight: highlight, client: client, onTeamTap: onTeamTap)
        }
        hosting.rootView = HostedScreen(theme: theme, navigation: navigation, content: view)
    }
}

/// Un composant en plein écran : défilant, sur le fond du thème, avec le thème et le routeur de
/// l'écran UIKit.
struct HostedScreen<Content: View>: View {
    let theme: IdalgoTheme?
    let navigation: (@MainActor (IdalgoDestination) -> IdalgoNavigationResult)?
    let content: Content

    var body: some View {
        Group {
            if let navigation {
                ScrollView { content }.idalgoNavigation(navigation)
            } else {
                ScrollView { content }
            }
        }
        .modifier(ScreenBackground())
        .environment(\.idalgoTheme, theme)
    }
}

@MainActor
private func embed(_ child: UIViewController, in parent: UIViewController) {
    parent.addChild(child)
    child.view.translatesAutoresizingMaskIntoConstraints = false
    child.view.backgroundColor = .clear
    parent.view.addSubview(child.view)
    NSLayoutConstraint.activate([
        child.view.topAnchor.constraint(equalTo: parent.view.topAnchor),
        child.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor),
        child.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
        child.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
    ])
    child.didMove(toParent: parent)
}
#endif
