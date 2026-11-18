import SwiftUI

/// Sélecteur à segments aux couleurs du thème (le `Picker` segmenté du système ne se thème pas).
struct SegmentedPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    let accessibilityLabel: String

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Button { selection = option } label: {
                    Text(label(option))
                        .font(theme.bodyFont.font(.subheadline, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: height)
                        .foregroundStyle(selected ? theme.onPrimary : theme.text)
                        .background(
                            RoundedRectangle(cornerRadius: max(theme.radius.s - 2, 0))
                                .fill(selected ? theme.primary : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: theme.radius.s).fill(theme.surface))
        .animation(.easeOut(duration: 0.15), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
