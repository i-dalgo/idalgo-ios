import SwiftUI

/// Rangée de puces défilante, une seule choisie ; la puce choisie reste visible.
struct ChipPicker: View {
    struct Option: Identifiable, Equatable {
        let id: String
        let label: String
        /// Compte affiché après le libellé (« En cours 2 »), s'il est positif.
        var count: Int?
    }

    let options: [Option]
    @Binding var selection: String?
    let accessibilityLabel: String

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .footnote) private var height: CGFloat = 32

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        chip(option)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
            .onChange(of: selection) { id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func chip(_ option: Option) -> some View {
        let selected = option.id == selection
        return Button { selection = option.id } label: {
            HStack(spacing: 5) {
                Text(option.label)
                if let count = option.count, count > 0 {
                    Text(String(count)).monospacedDigit().opacity(0.7)
                }
            }
                .font(theme.bodyFont.font(.footnote, weight: selected ? .semibold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: height)
                .foregroundStyle(selected ? theme.onPrimary : theme.text)
                .background(Capsule().fill(selected ? theme.primary : theme.surface))
                .overlay(Capsule().strokeBorder(selected ? .clear : theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .id(option.id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
