import SwiftUI

/// Classement d'une saison, natif : en-tête, choix général / domicile / extérieur, choix de la
/// poule quand il y en a plusieurs, puis le tableau (place, logo et nom figés, statistiques de
/// l'API dans l'ordre, qui défilent si elles ne tiennent pas).
///
/// La vue prend sa hauteur naturelle : placez-la dans une `ScrollView`. Changer `season`,
/// `competition` ou `group` relit le classement sans recréer la vue.
///
/// ```swift
/// ScrollView {
///     IdalgoStandingsView(competition: "103", highlight: ["24803"], limit: 5) { team in
///         print("Équipe touchée :", team.name ?? team.id)
///     }
/// }
/// ```
public struct IdalgoStandingsView: View {
    private let source: StandingsModel.Source
    private let group: String?
    private let highlight: Set<String>
    private let client: IdalgoClient?
    private let display: StandingsDisplay
    private let onTeamTap: ((TeamCompetitor) -> Void)?

    @StateObject private var model: StandingsModel

    /// - Parameters:
    ///   - season: id de la saison.
    ///   - group: id d'une poule, pour n'afficher qu'elle.
    ///   - split: classement affiché d'abord (le lecteur peut en changer).
    ///   - highlight: ids des équipes à mettre en avant.
    ///   - limit: les N premières lignes seulement (« top 5 »).
    ///   - around: lignes gardées de part et d'autre de chaque équipe mise en avant ; avec `limit`,
    ///     les deux morceaux, séparés par « ··· ».
    ///   - showsSplitSelector: choix général / domicile / extérieur.
    ///   - showsHeader: bandeau de la compétition (logo, saison, journée).
    ///   - compact: colonnes réduites à l'essentiel (J, Diff, Pts ; V, D, %).
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    ///   - onTeamTap: appelé au toucher d'une équipe, avant le routeur de l'app (`.idalgoNavigation`).
    public init(
        season: String,
        group: String? = nil,
        split: StandingSplit = .overall,
        highlight: [String] = [],
        limit: Int? = nil,
        around: Int? = nil,
        showsSplitSelector: Bool = true,
        showsHeader: Bool = true,
        compact: Bool = false,
        client: IdalgoClient? = nil,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        self.init(
            source: .season(season), group: group, split: split, highlight: highlight,
            display: StandingsDisplay(
                limit: limit, around: around, showsSplitSelector: showsSplitSelector,
                showsHeader: showsHeader, compact: compact
            ),
            client: client, onTeamTap: onTeamTap
        )
    }

    /// Le classement de la saison en cours d'une compétition (`currentSeason` de
    /// `/v1/competitions`, lu une fois par client) : il suit la compétition d'une saison à l'autre.
    /// Mêmes paramètres que `init(season:…)`.
    public init(
        competition: String,
        group: String? = nil,
        split: StandingSplit = .overall,
        highlight: [String] = [],
        limit: Int? = nil,
        around: Int? = nil,
        showsSplitSelector: Bool = true,
        showsHeader: Bool = true,
        compact: Bool = false,
        client: IdalgoClient? = nil,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        self.init(
            source: .competition(competition), group: group, split: split, highlight: highlight,
            display: StandingsDisplay(
                limit: limit, around: around, showsSplitSelector: showsSplitSelector,
                showsHeader: showsHeader, compact: compact
            ),
            client: client, onTeamTap: onTeamTap
        )
    }

    /// Classements déjà lus (par exemple ceux d'une feuille de match), sans appel à l'API : le
    /// choix général / domicile / extérieur ne propose que les splits donnés.
    /// - Parameters:
    ///   - standings: classements par split ; `overall` au moins.
    ///   - highlight: ids des équipes à mettre en avant ; la poule affichée d'abord est la leur.
    ///   - limit, around, showsSplitSelector, showsHeader, compact: comme `init(season:…)`.
    ///   - onTeamTap: appelé au toucher d'une équipe.
    public init(
        standings: [StandingSplit: Standings],
        highlight: [String] = [],
        limit: Int? = nil,
        around: Int? = nil,
        showsSplitSelector: Bool = true,
        showsHeader: Bool = true,
        compact: Bool = false,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        self.init(
            source: .preloaded(standings), group: nil, split: .overall, highlight: highlight,
            display: StandingsDisplay(
                limit: limit, around: around, showsSplitSelector: showsSplitSelector,
                showsHeader: showsHeader, compact: compact
            ),
            client: nil, onTeamTap: onTeamTap
        )
    }

    init(
        source: StandingsModel.Source,
        group: String?,
        split: StandingSplit,
        highlight: [String],
        display: StandingsDisplay,
        client: IdalgoClient?,
        onTeamTap: ((TeamCompetitor) -> Void)?
    ) {
        self.source = source
        self.group = group
        self.highlight = Set(highlight)
        self.client = client
        self.display = display
        self.onTeamTap = onTeamTap
        _model = StateObject(wrappedValue: StandingsModel(split: split))
    }

    public var body: some View {
        let request = model.request(source, group: group)
        StandingsContent(
            model: model,
            splits: StandingsModel.splits(for: source),
            highlight: highlight,
            display: display,
            onTeamTap: onTeamTap
        )
        .modifier(ThemedContainer())
        .task(id: request) {
            await model.load(request, client: client ?? Idalgo.client, highlight: highlight)
        }
    }
}

/// Réglages d'affichage du classement.
struct StandingsDisplay {
    var limit: Int?
    var around: Int?
    var showsSplitSelector = true
    var showsHeader = true
    var compact = false
}

/// Le contenu selon l'état : squelette, erreur, classement.
private struct StandingsContent: View {
    @ObservedObject var model: StandingsModel
    let splits: [StandingSplit]
    let highlight: Set<String>
    let display: StandingsDisplay
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        switch model.phase {
        case .loading:
            LoadingStateSlot(label: IdalgoStrings.loading, rows: display.limit.map { min($0, 10) } ?? 10)
        case .unsupported:
            EmptyStateSlot(message: IdalgoStrings.standingsUnsupported)
        case let .failed(error):
            ErrorStateSlot(
                error: error,
                title: IdalgoStrings.standingsUnavailable,
                fallback: IdalgoStrings.standingsLoadFailed,
                retry: { model.retry() }
            )
        case let .loaded(presentation):
            StandingsBody(
                presentation: display.compact ? presentation.compacted() : presentation,
                groupID: Binding(get: { model.selectedGroupID }, set: { model.selectedGroupID = $0 }),
                split: splits.count > 1 && display.showsSplitSelector ? $model.split : nil,
                splits: splits,
                highlight: highlight,
                display: display,
                onTeamTap: NavigationContext(navigator: navigator, opener: opener).teamHandler(shortcut: onTeamTap)
            )
            .opacity(model.isRefreshing ? 0.4 : 1)
            .overlay { if model.isRefreshing { ProgressView() } }
            .animation(.easeOut(duration: 0.2), value: model.isRefreshing)
        }
    }
}

/// Un classement lu : bandeau, choix du split et de la poule, tableau. Partagé par le widget et la
/// brique `IdalgoStandingsTable`.
struct StandingsBody: View {
    let presentation: StandingsPresentation
    /// Poule choisie ; `nil` en lecture seule (brique) : la préférée est montrée, sans choix.
    let groupID: Binding<String?>?
    let split: Binding<StandingSplit>?
    let splits: [StandingSplit]
    let highlight: Set<String>
    let display: StandingsDisplay
    let onTeamTap: ((TeamCompetitor) -> Void)?
    var preferredGroup: String?

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        let groups = presentation.groups
        let selected = groupID?.wrappedValue ?? preferredGroup
        let group = StandingsPresentation.Group.preferred(in: groups, highlight: highlight, id: selected)
        VStack(alignment: .leading, spacing: theme.dense(12)) {
            if display.showsHeader || group?.dayLabel != nil {
                StandingsHeader(
                    title: display.showsHeader ? presentation.title : nil,
                    logo: display.showsHeader ? presentation.competitionLogo : nil,
                    dayLabel: group?.dayLabel
                )
                .padding(.horizontal, 16)
            }
            if let split {
                SegmentedPicker(
                    options: splits,
                    selection: split,
                    label: IdalgoStrings.split,
                    accessibilityLabel: IdalgoStrings.splitPicker
                )
                .padding(.horizontal, 16)
            }
            if let groupID, groups.count > 1 {
                ChipPicker(
                    options: groups.map { .init(id: $0.id, label: $0.name) },
                    selection: groupID,
                    accessibilityLabel: IdalgoStrings.groupPicker
                )
            }
            if let group, !group.rows.isEmpty {
                StandingsTableView(
                    columns: presentation.columns,
                    items: StandingsWindow.items(group.rows, highlight: highlight, limit: display.limit, around: display.around),
                    showsEvolution: presentation.showsEvolution,
                    highlight: highlight,
                    onTeamTap: onTeamTap
                )
            } else {
                EmptyStateSlot(message: IdalgoStrings.standingsEmpty)
            }
        }
        .padding(.vertical, display.showsHeader ? theme.dense(12) : 0)
    }
}

/// Logo de la compétition, nom de la saison et date de la dernière journée prise en compte.
private struct StandingsHeader: View {
    let title: String?
    let logo: Logo?
    let dayLabel: String?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var logoSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 10) {
            if let logo {
                LogoImage(logo: logo, size: logoSize) { Color.clear }
            }
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .font(theme.headingFont.font(.headline, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                }
                if let dayLabel {
                    Text(dayLabel)
                        .font(theme.bodyFont.font(.caption))
                        .foregroundStyle(theme.secondary)
                }
            }
        }
    }
}
