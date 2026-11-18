import SwiftUI

/// L'en-tête de la feuille de match, seul : contexte et date, les deux équipes de part et d'autre
/// du score (ou de l'heure), la mi-temps, l'état du match et les buteurs. Brique sans état : elle
/// affiche la feuille donnée (`IdalgoMatchSheetModel.sheet`, `IdalgoClient.matchSheet`).
public struct IdalgoMatchHeader: View {
    private let contest: HeadToHeadContestDetail
    private let actions: [ContestAction]
    private let standings: Standings?
    private let timeZone: TimeZone
    private let onTeamTap: ((TeamCompetitor) -> Void)?

    /// - Parameters:
    ///   - sheet: la feuille du match : buteurs et place au classement compris.
    ///   - timeZone: fuseau IANA de la date ; par défaut, celui de l'appareil.
    ///   - onTeamTap: appelé au toucher d'une équipe, avant le routeur de l'app.
    public init(sheet: MatchSheet, timeZone: String? = nil, onTeamTap: ((TeamCompetitor) -> Void)? = nil) {
        self.init(contest: sheet.contest, actions: sheet.actions, standings: sheet.standings.overall, timeZone: timeZone, onTeamTap: onTeamTap)
    }

    /// L'en-tête d'un match seul (`MatchSheet.contest`, ou le `contest` d'une lecture live), sans
    /// buteurs ni place au classement.
    public init(contest: HeadToHeadContestDetail, timeZone: String? = nil, onTeamTap: ((TeamCompetitor) -> Void)? = nil) {
        self.init(contest: contest, actions: [], standings: nil, timeZone: timeZone, onTeamTap: onTeamTap)
    }

    private init(
        contest: HeadToHeadContestDetail,
        actions: [ContestAction],
        standings: Standings?,
        timeZone: String?,
        onTeamTap: ((TeamCompetitor) -> Void)?
    ) {
        self.contest = contest
        self.actions = actions
        self.standings = standings
        self.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        self.onTeamTap = onTeamTap
    }

    public var body: some View {
        MatchHeaderBlock(
            header: MatchSheetHeader(contest: contest, actions: actions, standings: standings, timeZone: timeZone),
            contest: contest,
            onTeamTap: onTeamTap
        )
        .modifier(BlockTheming())
    }
}

/// L'en-tête, ses équipes touchables par le raccourci ou le routeur de l'app.
private struct MatchHeaderBlock: View {
    let header: MatchSheetHeader
    let contest: HeadToHeadContestDetail
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        let tap = NavigationContext(navigator: navigator, opener: opener).teamHandler(shortcut: onTeamTap)
        MatchHeaderView(header: header, onTeamTap: tap.map { tap in
            { side in
                let competitor = side == .home ? contest.home.competitor : contest.away.competitor
                if case let .team(team) = competitor { tap(team) }
            }
        })
    }
}

/// Le fil du match, seul (rubrique Actions) : actions du domicile à gauche, de l'extérieur à
/// droite, minute au centre, coupures à la mi-temps et à la fin avec le score.
public struct IdalgoActionsTimeline: View {
    private let sheet: MatchSheet

    /// - Parameter sheet: la feuille du match.
    public init(sheet: MatchSheet) {
        self.sheet = sheet
    }

    public var body: some View {
        MatchSheetTabContent(sheet: sheet, tab: .actions, timeZone: .current, onTeamTap: nil)
            .modifier(BlockTheming())
    }
}

/// Les compositions, seules (rubrique Compos) : le terrain (titulaires à leurs places, badges but,
/// carton, sortie, capitaine), l'entraîneur et les remplaçants ; un choix d'équipe s'il y en a deux.
public struct IdalgoLineupPitch: View {
    private let sheet: MatchSheet
    private let side: Side?

    /// - Parameters:
    ///   - sheet: la feuille du match.
    ///   - side: une seule équipe (sans choix) ; `nil` : les deux, au choix du lecteur.
    public init(sheet: MatchSheet, side: Side? = nil) {
        self.sheet = sheet
        self.side = side
    }

    public var body: some View {
        LineupsTabView(lineups: lineups, marks: MatchActions.playerMarks(sheet.actions))
            .modifier(BlockTheming())
    }

    private var lineups: [Lineup] {
        guard let side else { return sheet.lineups }
        let id = side == .home ? sheet.contest.home.competitor.id : sheet.contest.away.competitor.id
        return sheet.lineups.filter { $0.competitor.id == id }
    }
}

/// L'avant-match, seul (rubrique Avant-match) : forme récente, classement à la date du match,
/// joueurs clés, confrontations.
public struct IdalgoPreMatch: View {
    private let sheet: MatchSheet
    private let timeZone: TimeZone
    private let onTeamTap: ((TeamCompetitor) -> Void)?

    /// - Parameters:
    ///   - sheet: la feuille du match.
    ///   - timeZone: fuseau IANA des dates des confrontations ; par défaut, celui de l'appareil.
    ///   - onTeamTap: appelé au toucher d'une équipe du classement, avant le routeur de l'app.
    public init(sheet: MatchSheet, timeZone: String? = nil, onTeamTap: ((TeamCompetitor) -> Void)? = nil) {
        self.sheet = sheet
        self.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        self.onTeamTap = onTeamTap
    }

    public var body: some View {
        PreMatchBlock(sheet: sheet, timeZone: timeZone, onTeamTap: onTeamTap).modifier(BlockTheming())
    }
}

private struct PreMatchBlock: View {
    let sheet: MatchSheet
    let timeZone: TimeZone
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        let tap = NavigationContext(navigator: navigator, opener: opener).teamHandler(shortcut: onTeamTap)
        MatchSheetTabContent(sheet: sheet, tab: .preview, timeZone: timeZone, onTeamTap: tap)
    }
}
