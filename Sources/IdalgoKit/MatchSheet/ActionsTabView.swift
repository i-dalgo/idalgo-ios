import SwiftUI

/// Le fil du match : actions du domicile à gauche, de l'extérieur à droite, minute au centre ;
/// une coupure à la mi-temps et à la fin du match, avec le score.
struct ActionsTabView: View {
    let rows: [TimelineRow]
    let homeName: String
    let awayName: String

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .caption) private var minuteWidth: CGFloat = 44

    var body: some View {
        if rows.isEmpty {
            MessageStateView(message: IdalgoStrings.noActions)
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    switch row {
                    case let .action(action, kind, score):
                        actionRow(action, kind: kind, score: score)
                    case let .pause(label, score):
                        pause(label, score: score)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func actionRow(_ action: ContestAction, kind: ActionKind, score: MatchScore?) -> some View {
        let team = action.side.map { $0 == .home ? homeName : awayName }
        return HStack(spacing: 0) {
            Group {
                if action.side == .home { event(action, kind: kind, score: score, leading: false) } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            Text(MatchSheetFormat.minute(action.minute))
                .font(theme.bodyFont.font(.caption, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .frame(width: minuteWidth)
            Group {
                if action.side != .home { event(action, kind: kind, score: score, leading: true) } else { Color.clear }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, theme.dense(8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MatchActions.accessibilityLabel(action, kind: kind, score: score, team: team))
    }

    /// Icône, auteur, seconde personne (joueur sortant) et score après un but.
    private func event(_ action: ContestAction, kind: ActionKind, score: MatchScore?, leading: Bool) -> some View {
        let alignment: HorizontalAlignment = leading ? .leading : .trailing
        let texts = VStack(alignment: alignment, spacing: 1) {
            Text(MatchSheetFormat.lastName(action.person?.name ?? action.label))
                .font(theme.bodyFont.font(.subheadline, weight: kind.isHighlight ? .semibold : .regular))
                .lineLimit(2)
                .multilineTextAlignment(leading ? .leading : .trailing)
            if kind == .substitution, let leaving = action.relatedPerson {
                Text(MatchSheetFormat.lastName(leaving.name))
                    .font(theme.bodyFont.font(.caption))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            } else if case let .other(label) = kind {
                Text(label)
                    .font(theme.bodyFont.font(.caption))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        return HStack(spacing: 8) {
            if leading {
                ActionIcon(kind: kind)
                texts
                scoreChip(score)
            } else {
                scoreChip(score)
                texts
                ActionIcon(kind: kind)
            }
        }
    }

    @ViewBuilder
    private func scoreChip(_ score: MatchScore?) -> some View {
        if let score {
            Text(score.text)
                .font(theme.bodyFont.font(.caption, weight: .bold))
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(theme.onPrimary)
                .background(Capsule().fill(theme.primary))
        }
    }

    private func pause(_ label: String, score: MatchScore) -> some View {
        HStack(spacing: 10) {
            theme.border.frame(height: 1)
            Text("\(label) · \(score.text)")
                .font(theme.bodyFont.font(.caption, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .fixedSize()
            theme.border.frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

extension ActionKind {
    /// But ou carton rouge : l'auteur en gras.
    var isHighlight: Bool {
        switch self {
        case .goal, .ownGoal, .redCard, .secondYellowCard: true
        default: false
        }
    }
}
