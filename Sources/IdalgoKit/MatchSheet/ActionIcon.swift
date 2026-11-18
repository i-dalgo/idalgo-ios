import SwiftUI

/// Icône d'une action : ballon, carton, remplacement, tir au but.
struct ActionIcon: View {
    let kind: ActionKind

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 16

    var body: some View {
        Group {
            switch kind {
            case .goal: symbol("soccerball", theme.text)
            case .ownGoal: symbol("soccerball", theme.negative)
            case .yellowCard: card(theme.yellowCard)
            case .redCard: card(theme.redCard)
            case .secondYellowCard:
                ZStack {
                    card(theme.yellowCard).offset(x: -2, y: -1)
                    card(theme.redCard).offset(x: 2, y: 1)
                }
            case .substitution:
                HStack(spacing: -1) {
                    Image(systemName: "arrow.up").foregroundStyle(theme.positive)
                    Image(systemName: "arrow.down").foregroundStyle(theme.negative)
                }
                .font(.system(size: size * 0.7, weight: .bold))
            case .shootoutScored: symbol("checkmark.circle.fill", theme.positive)
            case .shootoutMissed: symbol("xmark.circle.fill", theme.negative)
            case .other: Circle().fill(theme.textSecondary).frame(width: size * 0.4, height: size * 0.4)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name).font(.system(size: size * 0.9, weight: .semibold)).foregroundStyle(color)
    }

    private func card(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: size * 0.55, height: size * 0.75)
    }
}
