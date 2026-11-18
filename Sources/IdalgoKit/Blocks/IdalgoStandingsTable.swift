import SwiftUI

/// Le tableau d'un classement déjà lu, sans choix ni lecture : la poule demandée, sinon celle des
/// équipes mises en avant, ou la première. Pour une carte « top 5 » ou les équipes autour de la
/// sienne.
///
/// ```swift
/// let standings = try await Idalgo.client.standings(season: "374703")
/// IdalgoStandingsTable(standings: standings, highlight: ["24803"], limit: 5, compact: true)
/// ```
public struct IdalgoStandingsTable: View {
    private let presentation: StandingsPresentation?
    private let highlight: Set<String>
    private let group: String?
    private let display: StandingsDisplay
    private let onTeamTap: ((TeamCompetitor) -> Void)?

    /// - Parameters:
    ///   - standings: le classement (`IdalgoClient.standings`, `MatchSheet.standings`).
    ///   - highlight: ids des équipes à mettre en avant.
    ///   - group: id de la poule à montrer ; par défaut, celle des équipes mises en avant.
    ///   - limit: les N premières lignes seulement.
    ///   - around: lignes gardées de part et d'autre de chaque équipe mise en avant ; avec `limit`,
    ///     les deux morceaux, séparés par « ··· ».
    ///   - compact: colonnes réduites à l'essentiel (J, Diff, Pts ; V, D, %).
    ///   - showsHeader: bandeau de la compétition (logo, saison, journée).
    ///   - onTeamTap: appelé au toucher d'une équipe, avant le routeur de l'app.
    public init(
        standings: Standings,
        highlight: [String] = [],
        group: String? = nil,
        limit: Int? = nil,
        around: Int? = nil,
        compact: Bool = false,
        showsHeader: Bool = true,
        onTeamTap: ((TeamCompetitor) -> Void)? = nil
    ) {
        presentation = StandingsPresentation(standings)
        self.highlight = Set(highlight)
        self.group = group
        display = StandingsDisplay(limit: limit, around: around, showsSplitSelector: false, showsHeader: showsHeader, compact: compact)
        self.onTeamTap = onTeamTap
    }

    public var body: some View {
        TableBlock(presentation: presentation, highlight: highlight, group: group, display: display, onTeamTap: onTeamTap)
            .modifier(BlockTheming())
    }
}

private struct TableBlock: View {
    let presentation: StandingsPresentation?
    let highlight: Set<String>
    let group: String?
    let display: StandingsDisplay
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        if let presentation {
            StandingsBody(
                presentation: display.compact ? presentation.compacted() : presentation,
                groupID: nil,
                split: nil,
                splits: [],
                highlight: highlight,
                display: display,
                onTeamTap: NavigationContext(navigator: navigator, opener: opener).teamHandler(shortcut: onTeamTap),
                preferredGroup: group
            )
        } else {
            EmptyStateSlot(message: IdalgoStrings.standingsUnsupported)
        }
    }
}
