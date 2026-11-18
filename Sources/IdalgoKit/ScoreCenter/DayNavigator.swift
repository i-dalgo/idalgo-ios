import SwiftUI

/// En-tête du jour : flèches vers les jours voisins qui ont des matchs, libellé au centre.
struct DayNavigator: View {
    let label: String
    let subtitle: String?
    let canGoBack: Bool
    let canGoForward: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .headline) private var arrowSize: CGFloat = 36

    var body: some View {
        HStack(spacing: 8) {
            arrow("chevron.left", enabled: canGoBack, label: IdalgoStrings.previousDay, action: onPrevious)
            VStack(spacing: 1) {
                Text(label)
                    .font(theme.headingFont.font(.headline, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(theme.bodyFont.font(.caption))
                        .foregroundStyle(theme.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            arrow("chevron.right", enabled: canGoForward, label: IdalgoStrings.nextDay, action: onNext)
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: arrowSize, height: arrowSize)
                .foregroundStyle(enabled ? theme.primary : theme.textSecondary.opacity(0.4))
                .background(Circle().fill(theme.surface))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
