import SwiftUI

/// Une ligne de match : domicile à gauche, heure ou score au centre, extérieur à droite. Une
/// épreuve classée tient sur une ligne : son nom et son état.
struct ContestRowView: View {
    let row: ScoreCenterPresentation.Row
    /// Remplace « Terminé » sous le score (date d'une confrontation passée).
    var caption: String?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var regularHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .subheadline) private var compactHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 26
    @ScaledMetric(relativeTo: .headline) private var centreWidth: CGFloat = 76

    var body: some View {
        Group {
            switch row.kind {
            case let .headToHead(home, away):
                HStack(spacing: 8) {
                    side(home, leading: false)
                    ContestCentre(state: row.state, home: home, away: away, finishedCaption: caption).frame(width: centreWidth)
                    side(away, leading: true)
                }
            case let .ranked(title):
                HStack(spacing: 12) {
                    Text(title)
                        .font(theme.bodyFont.font(.subheadline, weight: .medium))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ContestCentre(state: row.state, home: nil, away: nil, finishedCaption: caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, theme.dense(8))
        .frame(minHeight: theme.isCompact ? compactHeight : regularHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }

    /// Nom et logo d'un camp ; le domicile se lit vers le centre (nom aligné à droite).
    private func side(_ side: ScoreCenterPresentation.Side, leading: Bool) -> some View {
        let name = Text(side.name)
            .font(theme.bodyFont.font(.subheadline, weight: side.isWinner ? .bold : .regular))
            .foregroundStyle(side.isLoser ? theme.textSecondary : theme.text)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(leading ? .leading : .trailing)
        let logo = TeamLogoView(logo: side.image, name: side.name, size: logoSize)
        return HStack(spacing: 8) {
            if leading {
                logo
                name
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                name
                logo
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Centre d'une ligne : heure à venir, score et minute en direct, score final, ou état.
private struct ContestCentre: View {
    let state: ScoreCenterPresentation.State
    let home: ScoreCenterPresentation.Side?
    let away: ScoreCenterPresentation.Side?
    let finishedCaption: String?

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            switch state {
            case let .scheduled(time):
                Text(time ?? "—")
                    .font(theme.bodyFont.font(.subheadline, weight: .semibold))
                    .monospacedDigit()
            case let .live(label):
                score.foregroundStyle(theme.live)
                HStack(spacing: 4) {
                    PulsingDot()
                    Text(label ?? IdalgoStrings.live)
                        .font(theme.bodyFont.font(.caption2, weight: .semibold))
                        .foregroundStyle(theme.live)
                        .lineLimit(1)
                }
            case .finished:
                score
                caption(finishedCaption ?? IdalgoStrings.finished)
            case .postponed:
                caption(IdalgoStrings.postponed)
            case .cancelled:
                caption(IdalgoStrings.cancelled)
            case let .other(label):
                caption(label)
            }
        }
        .minimumScaleFactor(0.8)
    }

    /// « 2 – 1 », le vainqueur en gras ; sans score connu, un tiret.
    private var score: some View {
        Group {
            if let homeScore = home?.score, let awayScore = away?.score {
                Text(homeScore).fontWeight(weight(home)) + Text(" – ") + Text(awayScore).fontWeight(weight(away))
            } else {
                Text("–")
            }
        }
        .font(theme.bodyFont.font(.headline))
        .monospacedDigit()
        .lineLimit(1)
    }

    private func weight(_ side: ScoreCenterPresentation.Side?) -> Font.Weight {
        side?.isLoser == true ? .regular : .bold
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(theme.bodyFont.font(.caption2, weight: .medium))
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
    }
}
