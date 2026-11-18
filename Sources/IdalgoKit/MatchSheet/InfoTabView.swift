import SwiftUI

/// Les informations du match : compétition, date, arbitres, stade, affluence.
struct InfoTabView: View {
    let rows: [InfoRow]

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .font(theme.bodyFont.font(.subheadline))
                        .foregroundStyle(theme.textSecondary)
                    Spacer(minLength: 8)
                    if let flag = row.flag {
                        CachedImage(url: flag.small.url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { Color.clear }
                            .frame(width: 16, height: 11)
                            .accessibilityHidden(true)
                    }
                    Text(row.value)
                        .font(theme.bodyFont.font(.subheadline, weight: .medium))
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, theme.dense(12))
                .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 8)
    }
}
