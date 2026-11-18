import SwiftUI

/// Les matchs d'un jour du Score Center, une section par compétition, à poser dans une `List` ou une
/// `LazyVStack` de l'app, entre ses propres lignes. Les lignes et bandeaux suivent les composants de
/// l'app (`.idalgoComponents`) et son routeur (`.idalgoNavigation`).
///
/// ```swift
/// List {
///     MaLigneDeUne()
///     if let day = model.day {
///         IdalgoContests(day: day, status: model.status)
///     }
/// }
/// .listStyle(.plain)
/// ```
public struct IdalgoContests: View {
    private let day: ScoreCenter
    private let status: IdalgoStatusFilter
    private let showsStandingsButton: Bool
    private let onContestTap: ((Contest) -> Void)?

    /// - Parameters:
    ///   - day: le jour lu (`IdalgoScoreCenterModel.day`, `IdalgoClient.scoreCenter`).
    ///   - status: filtre de statut appliqué aux matchs.
    ///   - showsStandingsButton: bouton « Classement » dans les bandeaux.
    ///   - onContestTap: appelé au toucher d'un match, avant le routeur de l'app.
    public init(
        day: ScoreCenter,
        status: IdalgoStatusFilter = .all,
        showsStandingsButton: Bool = true,
        onContestTap: ((Contest) -> Void)? = nil
    ) {
        self.day = day
        self.status = status
        self.showsStandingsButton = showsStandingsButton
        self.onContestTap = onContestTap
    }

    public var body: some View {
        let timeZone = TimeZone(identifier: day.timeZone) ?? .current
        ForEach(day.competitions.compactMap { ScoreCenterPresentation.block($0, filter: status, timeZone: timeZone) }) { block in
            ScoreCenterSectionContent(
                block: block,
                timeZone: timeZone,
                showsStandingsButton: showsStandingsButton,
                onContestTap: onContestTap
            )
        }
    }
}

/// Un bloc de compétition du Score Center (bandeau, puis ses matchs), en `Section` : à poser dans
/// une `List` ou une `LazyVStack` de l'app. Rien n'est affiché si aucun match ne passe le filtre.
public struct IdalgoScoreCenterSection: View {
    private let competition: ScoreCenterCompetition
    private let timeZone: TimeZone
    private let status: IdalgoStatusFilter
    private let showsStandingsButton: Bool
    private let onContestTap: ((Contest) -> Void)?

    /// - Parameters:
    ///   - competition: un bloc du jour (`ScoreCenter.competitions`).
    ///   - timeZone: fuseau IANA des heures (`ScoreCenter.timeZone`) ; par défaut, celui de l'appareil.
    ///   - status: filtre de statut appliqué aux matchs.
    ///   - showsStandingsButton: bouton « Classement » dans le bandeau.
    ///   - onContestTap: appelé au toucher d'un match, avant le routeur de l'app.
    public init(
        competition: ScoreCenterCompetition,
        timeZone: String? = nil,
        status: IdalgoStatusFilter = .all,
        showsStandingsButton: Bool = true,
        onContestTap: ((Contest) -> Void)? = nil
    ) {
        self.competition = competition
        self.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        self.status = status
        self.showsStandingsButton = showsStandingsButton
        self.onContestTap = onContestTap
    }

    public var body: some View {
        if let block = ScoreCenterPresentation.block(competition, filter: status, timeZone: timeZone) {
            ScoreCenterSectionContent(
                block: block,
                timeZone: timeZone,
                showsStandingsButton: showsStandingsButton,
                onContestTap: onContestTap
            )
        }
    }
}

/// Une section : le bandeau en en-tête, une ligne touchable par match.
struct ScoreCenterSectionContent: View {
    let block: ScoreCenterPresentation.Block
    let timeZone: TimeZone
    let showsStandingsButton: Bool
    let onContestTap: ((Contest) -> Void)?

    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        Section {
            ForEach(block.rows) { row in
                ContestRowButton(row: row, timeZone: timeZone, onContestTap: onContestTap)
                    .modifier(BlockTheming())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
        } header: {
            let destination = IdalgoDestination.standings(season: block.season.id, highlight: [])
            let context = NavigationContext(navigator: navigator, opener: opener)
            CompetitionHeaderSlot(options: IdalgoCompetitionHeaderOptions(
                competition: block.competition,
                season: block.season,
                title: block.title,
                subtitle: block.subtitle,
                logo: block.logo,
                showsStandingsButton: showsStandingsButton && block.hasStandings
                    && context.isActionable(destination, hasShortcut: false),
                openStandings: { context.go(destination) }
            ))
            .modifier(BlockTheming())
            .listRowInsets(EdgeInsets())
        }
    }
}

/// Une ligne de match touchable : raccourci de l'app, puis son routeur, puis la feuille du SDK
/// (pour un duel seulement).
struct ContestRowButton: View {
    let row: ScoreCenterPresentation.Row
    let timeZone: TimeZone
    let onContestTap: ((Contest) -> Void)?
    /// La ligne de l'app (`IdalgoComponents.contestRow`) ; non pour la brique `IdalgoContestRow`,
    /// qui est la ligne par défaut (et qu'une ligne de l'app peut reprendre).
    var usesSlot = true
    var showsSeparator = true

    @Environment(\.resolvedIdalgoTheme) private var theme
    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener

    var body: some View {
        let contest = row.contest
        let destination = IdalgoDestination.contest(id: contest.id)
        let context = NavigationContext(navigator: navigator, opener: contest.isHeadToHead ? opener : nil)
        let shortcut = onContestTap.map { tap in { tap(contest) } }
        let actionable = context.isActionable(destination, hasShortcut: shortcut != nil)
        Group {
            if usesSlot {
                ContestRowSlot(options: IdalgoContestRowOptions(contest: contest, timeZone: timeZone, row: row))
            } else {
                ContestRowView(row: row)
            }
        }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { if actionable { context.go(destination, shortcut: shortcut) } }
            .accessibilityAddTraits(actionable ? .isButton : [])
            .accessibilityAction { if actionable { context.go(destination, shortcut: shortcut) } }
            .overlay(alignment: .bottom) { if showsSeparator { theme.border.frame(height: 1 / 3) } }
    }
}

/// Bandeau d'un bloc : logo, nom, journée, bouton « Classement ».
struct CompetitionHeaderView: View {
    let options: IdalgoCompetitionHeaderOptions

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var logoSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 10) {
            if let logo = options.logo {
                LogoImage(logo: logo, size: logoSize) { Color.clear }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(options.title)
                    .font(theme.headingFont.font(.subheadline, weight: .bold))
                    .lineLimit(1)
                if let subtitle = options.subtitle {
                    Text(subtitle)
                        .font(theme.bodyFont.font(.caption))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if options.showsStandingsButton {
                Button(action: options.openStandings) {
                    Text(IdalgoStrings.standings)
                        .font(theme.bodyFont.font(.caption, weight: .semibold))
                        .foregroundStyle(theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(theme.primary.opacity(0.5), lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(IdalgoStrings.standings) — \(options.title)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, theme.dense(10))
        .frame(maxWidth: .infinity)
        .background(theme.surface)
        .textCase(nil)
    }
}

extension Contest {
    /// Un duel : la feuille de match du SDK ne couvre que ceux-là.
    var isHeadToHead: Bool {
        if case .headToHead = self { return true }
        return false
    }
}
