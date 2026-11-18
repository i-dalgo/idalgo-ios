import SwiftUI

/// La ligne d'un match du Score Center, seule : domicile à gauche, heure ou score au centre,
/// extérieur à droite (une épreuve classée : son nom et son état). Brique sans état : elle affiche
/// le match donné, déjà lu.
///
/// Touchée, elle appelle `onTap`, sinon le routeur de l'app (`.idalgoNavigation`), qui peut laisser
/// le SDK ouvrir la feuille du match ; sans l'un ni l'autre, elle n'est pas touchable.
///
/// ```swift
/// IdalgoContestRow(contest: contest) { contest in
///     path.append(contest.id)
/// }
/// ```
public struct IdalgoContestRow: View {
    private let contest: Contest
    private let timeZone: TimeZone
    private let onTap: ((Contest) -> Void)?

    /// - Parameters:
    ///   - contest: le match (`ScoreCenter.competitions[…].contests`, confrontations…).
    ///   - timeZone: fuseau IANA de l'heure affichée ; par défaut, celui de l'appareil.
    ///   - onTap: appelé au toucher, avant le routeur de l'app.
    public init(contest: Contest, timeZone: String? = nil, onTap: ((Contest) -> Void)? = nil) {
        self.contest = contest
        self.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        self.onTap = onTap
    }

    public var body: some View {
        if let row = ScoreCenterPresentation.row(contest, timeZone: timeZone) {
            ContestRowButton(row: row, timeZone: timeZone, onContestTap: onTap, usesSlot: false, showsSeparator: false)
                .modifier(BlockTheming())
        }
    }
}

/// Une carte compacte d'un match, pour un carrousel ou un écran d'accueil : compétition et état en
/// tête (heure, direct avec son point, « Terminé »), puis les deux équipes, logo, nom et score.
/// Elle prend la largeur qu'on lui donne (`.frame(width: 220)` dans un carrousel).
///
/// Touchée, elle appelle `onTap`, sinon le routeur de l'app (`.idalgoNavigation`).
///
/// ```swift
/// ScrollView(.horizontal) {
///     LazyHStack {
///         ForEach(contests) { contest in
///             IdalgoContestCard(contest: contest).frame(width: 220)
///         }
///     }
/// }
/// ```
public struct IdalgoContestCard: View {
    private let contest: Contest
    private let timeZone: TimeZone
    private let onTap: ((Contest) -> Void)?

    /// - Parameters:
    ///   - contest: le match.
    ///   - timeZone: fuseau IANA de l'heure affichée ; par défaut, celui de l'appareil.
    ///   - onTap: appelé au toucher, avant le routeur de l'app.
    public init(contest: Contest, timeZone: String? = nil, onTap: ((Contest) -> Void)? = nil) {
        self.contest = contest
        self.timeZone = timeZone.flatMap(TimeZone.init(identifier:)) ?? .current
        self.onTap = onTap
    }

    public var body: some View {
        if let row = ScoreCenterPresentation.row(contest, timeZone: timeZone) {
            ContestCardView(row: row, onTap: onTap).modifier(BlockTheming())
        }
    }
}

private struct ContestCardView: View {
    let row: ScoreCenterPresentation.Row
    let onTap: ((Contest) -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @Environment(\.idalgoNavigator) private var navigator
    @Environment(\.idalgoOpener) private var opener
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var competitionLogoSize: CGFloat = 14

    var body: some View {
        let contest = row.contest
        let destination = IdalgoDestination.contest(id: contest.id)
        let context = NavigationContext(navigator: navigator, opener: contest.isHeadToHead ? opener : nil)
        let shortcut = onTap.map { tap in { tap(contest) } }
        let actionable = context.isActionable(destination, hasShortcut: shortcut != nil)
        VStack(alignment: .leading, spacing: theme.dense(10)) {
            HStack(spacing: 6) {
                if let logo = competition.logo {
                    LogoImage(logo: logo, size: competitionLogoSize) { Color.clear }
                }
                Text(competition.name ?? "—")
                    .font(theme.bodyFont.font(.caption2, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                state
            }
            switch row.kind {
            case let .headToHead(home, away):
                VStack(alignment: .leading, spacing: theme.dense(6)) {
                    team(home)
                    team(away)
                }
            case let .ranked(title):
                Text(title)
                    .font(theme.bodyFont.font(.subheadline, weight: .semibold))
                    .lineLimit(2)
            }
        }
        .padding(theme.dense(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: theme.radius.m).fill(theme.surface))
        .overlay(RoundedRectangle(cornerRadius: theme.radius.m).strokeBorder(theme.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: theme.radius.m))
        .onTapGesture { if actionable { context.go(destination, shortcut: shortcut) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(actionable ? .isButton : [])
        .accessibilityAction { if actionable { context.go(destination, shortcut: shortcut) } }
    }

    private var competition: (name: String?, logo: Logo?) {
        switch row.contest {
        case let .headToHead(duel): (duel.competition.name, duel.competition.logo)
        case let .ranked(event): (event.competition.name, event.competition.logo)
        case .unsupported: (nil, nil)
        }
    }

    @ViewBuilder
    private var state: some View {
        switch row.state {
        case let .scheduled(time):
            label(time ?? "—", color: theme.text)
        case let .live(label):
            HStack(spacing: 4) {
                PulsingDot()
                self.label(label ?? IdalgoStrings.live, color: theme.live)
            }
        case .finished: label(IdalgoStrings.finished, color: theme.textSecondary)
        case .postponed: label(IdalgoStrings.postponed, color: theme.textSecondary)
        case .cancelled: label(IdalgoStrings.cancelled, color: theme.textSecondary)
        case let .other(text): label(text, color: theme.textSecondary)
        }
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(theme.bodyFont.font(.caption2, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func team(_ side: ScoreCenterPresentation.Side) -> some View {
        HStack(spacing: 8) {
            TeamLogoView(logo: side.image, name: side.name, size: logoSize)
            Text(side.name)
                .font(theme.bodyFont.font(.subheadline, weight: side.isWinner ? .bold : .medium))
                .foregroundStyle(side.isLoser ? theme.textSecondary : theme.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let score = side.score {
                Text(score)
                    .font(theme.headingFont.font(.headline, weight: side.isLoser ? .regular : .bold))
                    .monospacedDigit()
                    .foregroundStyle(row.state.isLive ? theme.live : (side.isLoser ? theme.textSecondary : theme.text))
            }
        }
    }
}
