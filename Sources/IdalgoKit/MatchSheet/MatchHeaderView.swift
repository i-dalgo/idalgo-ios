import SwiftUI

/// En-tête de la feuille : contexte et date, les deux équipes de part et d'autre du score (ou de
/// l'heure), la mi-temps, l'état du match et les buteurs.
struct MatchHeaderView: View {
    let header: MatchSheetHeader
    let onTeamTap: ((Side) -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .title) private var logoSize: CGFloat = 52

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(header.context)
                    .font(theme.bodyFont.font(.caption, weight: .semibold))
                    .foregroundStyle(theme.secondary)
                if let date = header.date {
                    Text(date)
                        .font(theme.bodyFont.font(.caption))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            HStack(alignment: .top, spacing: 8) {
                team(header.home, side: .home)
                centre.frame(minWidth: 96)
                team(header.away, side: .away)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(header.accessibilityLabel)
            .accessibilityAddTraits(.isHeader)
            if !header.home.scorers.isEmpty || !header.away.scorers.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    scorers(header.home.scorers, alignment: .trailing)
                    Image(systemName: "soccerball")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    scorers(header.away.scorers, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func team(_ team: MatchSheetHeader.Team, side: Side) -> some View {
        VStack(spacing: 6) {
            TeamLogoView(logo: team.image, name: team.name, size: logoSize)
            Text(team.name)
                .font(theme.headingFont.font(.subheadline, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let standing = team.standing {
                Text(standing)
                    .font(theme.bodyFont.font(.caption2))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTeamTap?(side) }
    }

    @ViewBuilder
    private var centre: some View {
        VStack(spacing: 4) {
            switch header.state {
            case let .scheduled(time):
                Text(time ?? "—")
                    .font(theme.headingFont.font(.title, weight: .bold))
                    .monospacedDigit()
                caption(IdalgoStrings.upcoming)
            case let .live(label):
                score.foregroundStyle(theme.live)
                HStack(spacing: 4) {
                    PulsingDot()
                    Text(label ?? IdalgoStrings.live)
                        .font(theme.bodyFont.font(.caption, weight: .bold))
                        .foregroundStyle(theme.live)
                }
            case .finished:
                score
                caption(IdalgoStrings.finished)
            case .postponed:
                caption(IdalgoStrings.postponed)
            case .cancelled:
                caption(IdalgoStrings.cancelled)
            case let .other(label):
                caption(label)
            }
            if let halfTime = header.halfTime {
                Text(halfTime)
                    .font(theme.bodyFont.font(.caption2))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var score: some View {
        let home = Text(header.home.score ?? "–").fontWeight(header.home.isLoser ? .regular : .bold)
        let away = Text(header.away.score ?? "–").fontWeight(header.away.isLoser ? .regular : .bold)
        return (home + Text(" – ") + away)
            .font(theme.headingFont.font(.largeTitle))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(theme.bodyFont.font(.caption, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
    }

    private func scorers(_ scorers: [Scorer], alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            ForEach(scorers) { scorer in
                Text(scorer.label)
                    .font(theme.bodyFont.font(.caption))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

/// Point du direct, qui pulse (fixe si les animations sont réduites).
struct PulsingDot: View {
    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        Circle()
            .fill(theme.live)
            .frame(width: 7, height: 7)
            .pulsing(dimmedOpacity: 0.25, duration: 0.9)
            .accessibilityHidden(true)
    }
}
