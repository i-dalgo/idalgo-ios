import SwiftUI

/// Feuille de match native : en-tête (équipes, score ou heure, buteurs), puis quatre rubriques
/// (Infos, Actions, Compos, Avant-match) sous des onglets qui restent visibles au défilement.
/// Pendant le match, l'en-tête, les actions et les compositions se relisent en direct.
///
/// La vue prend sa hauteur naturelle : placez-la dans une `ScrollView` (les onglets s'y épinglent).
/// Changer `contest` relit la feuille sans recréer la vue.
///
/// ```swift
/// ScrollView {
///     IdalgoMatchSheetView(contest: "54732603", tabs: [.actions, .lineups])
/// }
/// ```
public struct IdalgoMatchSheetView: View {
    private let contest: String
    private let client: IdalgoClient?
    private let options: Options
    private let external: IdalgoMatchSheetModel?

    @StateObject private var owned: IdalgoMatchSheetModel

    struct Options {
        let tabs: [MatchSheetTab]
        let showsHeader: Bool
        let timeZone: TimeZone
        let onTeamTap: ((TeamCompetitor) -> Void)?
    }

    /// - Parameters:
    ///   - contest: id du match.
    ///   - initialTab: rubrique ouverte d'emblée ; par défaut, les actions d'un match commencé,
    ///     l'avant-match sinon (ou la première de `tabs` si elle n'y est pas).
    ///   - tabs: rubriques proposées, dans cet ordre ; une seule : sans onglets.
    ///   - showsHeader: en-tête (équipes, score, buteurs) au-dessus des rubriques.
    ///   - timeZone: fuseau IANA des dates et heures ; par défaut, celui de l'appareil.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    ///   - onTeamTap: appelé au toucher d'une équipe (en-tête, classement), avant le routeur de
    ///     l'app (`.idalgoNavigation`).
    public init(
        contest: String,
        initialTab: MatchSheetTab? = nil,
        tabs: [MatchSheetTab] = MatchSheetTab.allCases,
        showsHeader: Bool = true,
        timeZone: String? = nil,
        client: IdalgoClient? = nil,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        self.contest = contest
        self.client = client
        options = Options(
            tabs: tabs,
            showsHeader: showsHeader,
            timeZone: timeZone.flatMap(TimeZone.init(identifier:)) ?? .current,
            onTeamTap: onTeamTap
        )
        external = nil
        _owned = StateObject(wrappedValue: IdalgoMatchSheetModel(contest: contest, initialTab: initialTab, client: client))
    }

    /// La feuille sur un état de l'app (`IdalgoMatchSheetModel`), partagé avec ses propres vues :
    /// match, rubrique et direct sont les siens. La vue le fait tourner tant qu'elle est affichée.
    public init(
        model: IdalgoMatchSheetModel,
        tabs: [MatchSheetTab] = MatchSheetTab.allCases,
        showsHeader: Bool = true,
        timeZone: String? = nil,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        contest = model.contest
        client = model.client
        options = Options(
            tabs: tabs,
            showsHeader: showsHeader,
            timeZone: timeZone.flatMap(TimeZone.init(identifier:)) ?? .current,
            onTeamTap: onTeamTap
        )
        external = model
        _owned = StateObject(wrappedValue: model)
    }

    public var body: some View {
        let model = external ?? owned
        MatchSheetContent(model: model, options: options)
            .modifier(ThemedContainer())
            .task(id: ContestInput(contest: contest, client: client)) {
                if external == nil {
                    model.contest = contest
                    model.client = client
                }
                await model.run()
            }
    }

    private struct ContestInput: Equatable {
        let contest: String
        let client: IdalgoClient?

        static func == (lhs: ContestInput, rhs: ContestInput) -> Bool {
            lhs.contest == rhs.contest && lhs.client === rhs.client
        }
    }
}

extension MatchSheetTab {
    /// Rubriques proposées : celles de l'app sans doublon, toutes si la liste est vide.
    static func visible(_ tabs: [MatchSheetTab]) -> [MatchSheetTab] {
        var seen = Set<MatchSheetTab>()
        let unique = tabs.filter { seen.insert($0).inserted }
        return unique.isEmpty ? allCases : unique
    }

    /// Rubrique affichée : la choisie si elle est proposée, sinon la première proposée.
    static func shown(_ selected: MatchSheetTab?, in tabs: [MatchSheetTab]) -> MatchSheetTab {
        selected.flatMap { tabs.contains($0) ? $0 : nil } ?? tabs[0]
    }
}

/// Le contenu selon l'état : squelette, erreur, feuille.
private struct MatchSheetContent: View {
    @ObservedObject var model: IdalgoMatchSheetModel
    let options: IdalgoMatchSheetView.Options

    @Environment(\.resolvedIdalgoTheme) private var theme
    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        switch model.phase {
        case .loading:
            LoadingStateSlot(label: IdalgoStrings.matchSheetLoading)
        case let .failed(error):
            ErrorStateSlot(
                error: error,
                title: IdalgoStrings.matchSheetUnavailable,
                fallback: IdalgoStrings.matchSheetLoadFailed,
                retry: { model.retry() }
            )
        case let .loaded(sheet):
            loaded(sheet)
        }
    }

    private func loaded(_ sheet: MatchSheet) -> some View {
        let tabs = MatchSheetTab.visible(options.tabs)
        let tab = MatchSheetTab.shown(model.tab, in: tabs)
        let onTeamTap = NavigationContext(navigator: navigator, opener: opener).teamHandler(shortcut: options.onTeamTap)
        return LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
            if options.showsHeader {
                MatchHeaderView(header: MatchSheetHeader(sheet, timeZone: options.timeZone), onTeamTap: onTeamTap.map { tap in
                    { side in
                        let competitor = side == .home ? sheet.contest.home.competitor : sheet.contest.away.competitor
                        if case let .team(team) = competitor { tap(team) }
                    }
                })
            }
            Section {
                MatchSheetTabContent(sheet: sheet, tab: tab, timeZone: options.timeZone, onTeamTap: onTeamTap)
            } header: {
                if tabs.count > 1 {
                    SegmentedPicker(
                        options: tabs,
                        selection: Binding(get: { tab }, set: { model.tab = $0 }),
                        label: IdalgoStrings.tab,
                        accessibilityLabel: IdalgoStrings.sections
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, theme.dense(8))
                    .background(theme.containerBackground == .clear ? AnyShapeStyle(.bar) : AnyShapeStyle(theme.background))
                    .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
                }
            }
        }
    }
}

/// Une rubrique de la feuille.
struct MatchSheetTabContent: View {
    let sheet: MatchSheet
    let tab: MatchSheetTab
    let timeZone: TimeZone
    let onTeamTap: ((TeamCompetitor) -> Void)?

    var body: some View {
        switch tab {
        case .info:
            InfoTabView(rows: InfoRow.rows(sheet.contest, timeZone: timeZone))
        case .actions:
            ActionsTabView(
                rows: MatchActions.timeline(sheet.actions, finished: sheet.contest.status == .finished),
                homeName: sheet.contest.home.competitor.name ?? "—",
                awayName: sheet.contest.away.competitor.name ?? "—"
            )
        case .lineups:
            LineupsTabView(lineups: sheet.lineups, marks: MatchActions.playerMarks(sheet.actions))
        case .preview:
            PreviewTabView(sheet: sheet, timeZone: timeZone, onTeamTap: onTeamTap)
        }
    }
}

extension NavigationContext {
    /// Toucher d'une équipe : le raccourci de l'app, puis son routeur ; `nil` si rien n'y répond
    /// (le SDK n'a pas d'écran d'équipe), la vue n'est alors pas présentée comme un bouton.
    @MainActor
    func teamHandler(shortcut: ((TeamCompetitor) -> Void)?) -> ((TeamCompetitor) -> Void)? {
        let probe = IdalgoDestination.team(id: "")
        guard isActionable(probe, hasShortcut: shortcut != nil) else { return nil }
        if let shortcut { return shortcut }
        guard let navigator else { return nil }
        return { team in
            MainActor.assumeIsolated { _ = navigator.route(.team(id: team.id)) }
        }
    }
}
