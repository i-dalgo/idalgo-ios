import SwiftUI

/// Score Center natif : les matchs d'un sport sur un jour, groupés par compétition. Flèches vers
/// les jours voisins qui ont des matchs, filtre de statut (appliqué au jour chargé), classement de
/// chaque compétition dans une feuille, et direct relu pendant les matchs.
///
/// La vue prend sa hauteur naturelle : placez-la dans une `ScrollView`. Changer `date`, `sport`,
/// `competitions` ou `timeZone` relit le jour sans recréer la vue.
///
/// ```swift
/// ScrollView {
///     IdalgoScoreCenterView(sport: "102", showsStatusFilter: false) { contest in
///         print("Match touché :", contest.id)
///     }
/// }
/// ```
public struct IdalgoScoreCenterView: View {
    private let inputs: Inputs
    private let options: Options
    private let external: IdalgoScoreCenterModel?
    private let onContestTap: ((Contest) -> Void)?

    @StateObject private var owned: IdalgoScoreCenterModel

    /// Entrées de l'app : en changer relit le jour.
    private struct Inputs: Equatable {
        let sport: String
        let competitions: [String]
        let date: String?
        let timeZone: String?
        let client: IdalgoClient?

        static func == (lhs: Inputs, rhs: Inputs) -> Bool {
            lhs.sport == rhs.sport && lhs.competitions == rhs.competitions && lhs.date == rhs.date
                && lhs.timeZone == rhs.timeZone && lhs.client === rhs.client
        }
    }

    /// Parties affichées.
    struct Options {
        var showsDayNavigator = true
        var showsStatusFilter = true
        var showsStandingsButton = true
    }

    /// - Parameters:
    ///   - sport: id du sport (`102` : football).
    ///   - competitions: compétitions affichées, dans l'ordre des blocs ; vide : la liste par défaut du sport.
    ///   - date: jour affiché d'abord (`AAAA-MM-JJ`) ; par défaut, aujourd'hui.
    ///   - timeZone: fuseau IANA du jour et des heures ; par défaut, celui de l'appareil.
    ///   - status: filtre de statut choisi d'abord (Tous par défaut).
    ///   - showsDayNavigator: flèches vers les jours voisins et libellé du jour.
    ///   - showsStatusFilter: puces Tous / En cours / Terminés / À venir.
    ///   - showsStandingsButton: bouton « Classement » dans le bandeau des blocs.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    ///   - onContestTap: appelé au toucher d'un match, avant le routeur de l'app (`.idalgoNavigation`).
    ///     Sans l'un ni l'autre, la feuille de match du SDK s'ouvre, dans le même fuseau : poussée
    ///     dans la pile de navigation s'il y en a une (`NavigationStack` ou `UINavigationController`
    ///     d'une app UIKit), sinon en feuille modale (`.idalgoContestPresentation(_:)`).
    public init(
        sport: String,
        competitions: [String] = [],
        date: String? = nil,
        timeZone: String? = nil,
        status: IdalgoStatusFilter = .all,
        showsDayNavigator: Bool = true,
        showsStatusFilter: Bool = true,
        showsStandingsButton: Bool = true,
        client: IdalgoClient? = nil,
        onContestTap: ((Contest) -> Void)? = nil
    ) {
        inputs = Inputs(sport: sport, competitions: competitions, date: date, timeZone: timeZone, client: client)
        options = Options(
            showsDayNavigator: showsDayNavigator,
            showsStatusFilter: showsStatusFilter,
            showsStandingsButton: showsStandingsButton
        )
        external = nil
        self.onContestTap = onContestTap
        _owned = StateObject(wrappedValue: IdalgoScoreCenterModel(
            sport: sport, competitions: competitions, date: date, timeZone: timeZone, status: status, client: client
        ))
    }

    /// Le Score Center sur un état de l'app (`IdalgoScoreCenterModel`), partagé avec ses propres
    /// vues : jour, filtre et direct sont les siens. La vue le fait tourner tant qu'elle est affichée.
    public init(
        model: IdalgoScoreCenterModel,
        showsDayNavigator: Bool = true,
        showsStatusFilter: Bool = true,
        showsStandingsButton: Bool = true,
        onContestTap: ((Contest) -> Void)? = nil
    ) {
        inputs = Inputs(sport: "", competitions: [], date: nil, timeZone: nil, client: nil)
        options = Options(
            showsDayNavigator: showsDayNavigator,
            showsStatusFilter: showsStatusFilter,
            showsStandingsButton: showsStandingsButton
        )
        external = model
        self.onContestTap = onContestTap
        _owned = StateObject(wrappedValue: model)
    }

    public var body: some View {
        let model = external ?? owned
        ScoreCenterContent(model: model, options: options, onContestTap: onContestTap)
            .modifier(ThemedContainer())
            .modifier(DestinationPresenter(client: model.client, timeZone: model.timeZone))
            .task(id: inputs) {
                if external == nil { apply(inputs, to: model) }
                await model.run()
            }
    }

    /// Reporte les entrées de l'app sur l'état ; seules celles qui changent relancent la lecture.
    private func apply(_ inputs: Inputs, to model: IdalgoScoreCenterModel) {
        model.sport = inputs.sport
        model.competitions = inputs.competitions
        model.timeZone = inputs.timeZone
        model.client = inputs.client
        model.date = inputs.date
    }
}

/// Le contenu selon l'état : squelette, erreur, jour chargé.
private struct ScoreCenterContent: View {
    @ObservedObject var model: IdalgoScoreCenterModel
    let options: IdalgoScoreCenterView.Options
    let onContestTap: ((Contest) -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        switch model.phase {
        case .loading:
            LoadingStateSlot(label: IdalgoStrings.scoreCenterLoading)
        case let .failed(error):
            ErrorStateSlot(
                error: error,
                title: IdalgoStrings.scoreCenterUnavailable,
                fallback: IdalgoStrings.scoreCenterLoadFailed,
                retry: { model.retry() }
            )
        case let .loaded(day):
            loaded(ScoreCenterPresentation(day, filter: model.status, now: Date()), day: day)
        }
    }

    private func loaded(_ presentation: ScoreCenterPresentation, day: ScoreCenter) -> some View {
        VStack(spacing: theme.dense(12)) {
            if options.showsDayNavigator {
                DayNavigator(
                    label: presentation.dayLabel,
                    subtitle: presentation.daySubtitle,
                    canGoBack: presentation.previousDate != nil && !model.isRefreshing,
                    canGoForward: presentation.nextDate != nil && !model.isRefreshing,
                    onPrevious: { model.showPreviousDay() },
                    onNext: { model.showNextDay() }
                )
                .padding(.horizontal, 16)
            }
            if options.showsStatusFilter {
                ChipPicker(
                    options: IdalgoStatusFilter.allCases.map {
                        .init(id: $0.rawValue, label: IdalgoStrings.filter($0).tab, count: presentation.counts[$0])
                    },
                    selection: Binding(
                        get: { model.status.rawValue },
                        set: { model.status = $0.flatMap(IdalgoStatusFilter.init(rawValue:)) ?? .all }
                    ),
                    accessibilityLabel: IdalgoStrings.statusFilter
                )
            }
            blocks(presentation, day: day)
                .opacity(model.isRefreshing ? 0.4 : 1)
                .overlay(alignment: .top) { if model.isRefreshing { ProgressView().padding(.top, 40) } }
                .animation(.easeOut(duration: 0.2), value: model.isRefreshing)
            if presentation.hasMoreContests {
                Text(IdalgoStrings.moreContests)
                    .font(theme.bodyFont.font(.footnote))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, theme.dense(12))
    }

    @ViewBuilder
    private func blocks(_ presentation: ScoreCenterPresentation, day: ScoreCenter) -> some View {
        if presentation.blocks.isEmpty {
            EmptyStateSlot(message: presentation.emptyMessage)
        } else {
            let timeZone = TimeZone(identifier: day.timeZone) ?? .current
            LazyVStack(spacing: theme.dense(16)) {
                ForEach(presentation.blocks) { block in
                    VStack(spacing: 0) {
                        ScoreCenterSectionContent(
                            block: block,
                            timeZone: timeZone,
                            showsStandingsButton: options.showsStandingsButton,
                            onContestTap: onContestTap
                        )
                    }
                }
            }
        }
    }
}
