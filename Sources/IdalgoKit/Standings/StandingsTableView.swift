import SwiftUI

/// Le tableau d'une poule : place, logo et nom figés à gauche, statistiques à droite, qui
/// défilent horizontalement quand elles ne tiennent pas dans la largeur.
struct StandingsTableView: View {
    let columns: [StandingsPresentation.Column]
    /// Lignes montrées, et coupures entre deux morceaux (`StandingsWindow`).
    let items: [StandingsWindow.Item]
    let showsEvolution: Bool
    let highlight: Set<String>
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var regularRowHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .subheadline) private var compactRowHeight: CGFloat = 36
    @ScaledMetric(relativeTo: .caption) private var gapHeight: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var headerHeight: CGFloat = 32
    @ScaledMetric(relativeTo: .footnote) private var characterWidth: CGFloat = 7.5
    @ScaledMetric(relativeTo: .footnote) private var minimumColumnWidth: CGFloat = 26
    @ScaledMetric(relativeTo: .subheadline) private var positionWidth: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var evolutionWidth: CGFloat = 10
    @ScaledMetric(relativeTo: .subheadline) private var logoSize: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var minimumIdentityWidth: CGFloat = 150
    @State private var width: CGFloat = 0

    private let edgePadding: CGFloat = 16
    private let separator: CGFloat = 1 / 3

    private var rowHeight: CGFloat { theme.isCompact ? compactRowHeight : regularRowHeight }

    var body: some View {
        let widths = columns.map(columnWidth)
        let statsWidth = widths.reduce(0, +) + edgePadding / 2
        let fits = width - statsWidth >= minimumIdentityWidth
        let identityWidth = fits ? width - statsWidth : max(minimumIdentityWidth, width * 0.42)

        HStack(alignment: .top, spacing: 0) {
            identityColumn.frame(width: identityWidth)
            ScrollView(.horizontal, showsIndicators: false) {
                statsColumn(widths: widths)
            }
            .scrollDisabled(fits)
            .overlay(alignment: .leading) {
                if !fits { theme.border.frame(width: separator) }
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
    }

    // MARK: Colonne figée

    private var identityColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                header(IdalgoStrings.positionHeader).frame(width: positionWidth)
                if showsEvolution { Spacer().frame(width: evolutionWidth) }
                header(IdalgoStrings.teamHeader)
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.leading, edgePadding)
            .frame(height: headerHeight)
            .background(theme.surface)
            .accessibilityHidden(true)

            ForEach(items) { item in
                switch item {
                case let .row(row): identityCell(row)
                case .gap: gap(label: true)
                }
            }
        }
    }

    private func identityCell(_ row: StandingsPresentation.Row) -> some View {
        HStack(spacing: 0) {
            Text(String(row.position))
                .font(theme.bodyFont.font(.subheadline, weight: .bold))
                .monospacedDigit()
                .frame(width: positionWidth)
            if showsEvolution {
                EvolutionMark(evolution: row.evolution).frame(width: evolutionWidth)
            }
            TeamLogoView(logo: row.competitor.logo, name: row.competitor.name, size: logoSize)
                .padding(.leading, 8)
            Text(row.competitor.name ?? "—")
                .font(theme.bodyFont.font(.subheadline, weight: highlight.contains(row.id) ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 8)
                .padding(.trailing, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, edgePadding)
        .rowStyle(height: rowHeight, highlighted: highlight.contains(row.id), theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { onTeamTap?(row.competitor) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityValue(row.accessibilityValue)
        .accessibilityHint(highlight.contains(row.id) ? IdalgoStrings.highlighted : "")
        .accessibilityAddTraits(onTeamTap == nil ? [] : .isButton)
        .accessibilityAction { onTeamTap?(row.competitor) }
    }

    // MARK: Statistiques

    private func statsColumn(widths: [CGFloat]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.element.id) { index, column in
                    header(column.header).frame(width: widths[index])
                }
            }
            .padding(.trailing, edgePadding / 2)
            .frame(height: headerHeight)
            .background(theme.surface)

            ForEach(items) { item in
                switch item {
                case let .row(row):
                    HStack(spacing: 0) {
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { index, cell in
                            statCell(cell, emphasized: columns[index].isEmphasized).frame(width: widths[index])
                        }
                    }
                    .padding(.trailing, edgePadding / 2)
                    .rowStyle(height: rowHeight, highlighted: highlight.contains(row.id), theme: theme)
                    .contentShape(Rectangle())
                    .onTapGesture { onTeamTap?(row.competitor) }
                case .gap:
                    gap(label: false)
                }
            }
        }
    }

    private func statCell(_ cell: StandingsPresentation.Cell, emphasized: Bool) -> some View {
        Text(cell.text)
            .font(theme.bodyFont.font(.footnote, weight: emphasized || cell.tone != .neutral ? .semibold : .regular))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(color(of: cell.tone))
    }

    /// Coupure entre deux morceaux du classement : « ··· » dans la colonne figée.
    private func gap(label: Bool) -> some View {
        Text(label ? "···" : "")
            .font(theme.bodyFont.font(.caption, weight: .bold))
            .foregroundStyle(theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, label ? edgePadding + 4 : 0)
            .frame(height: gapHeight)
            .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
            .accessibilityLabel(IdalgoStrings.standingsGap)
            .accessibilityHidden(!label)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(theme.bodyFont.font(.caption, weight: .semibold))
            .foregroundStyle(theme.textSecondary)
            .lineLimit(1)
    }

    private func color(of tone: StandingsPresentation.Tone) -> Color {
        switch tone {
        case .neutral: theme.text
        case .positive: theme.positive
        case .negative: theme.negative
        }
    }

    private func columnWidth(_ column: StandingsPresentation.Column) -> CGFloat {
        max(minimumColumnWidth, CGFloat(column.characterCount) * characterWidth + 8)
    }
}

/// Flèche d'évolution : montée en vert, descente en rouge, rien si la place n'a pas bougé.
private struct EvolutionMark: View {
    let evolution: StandingEvolution?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 7

    var body: some View {
        switch evolution {
        case .up: mark("arrowtriangle.up.fill", theme.positive)
        case .down: mark("arrowtriangle.down.fill", theme.negative)
        case nil: Color.clear
        }
    }

    private func mark(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
    }
}

private extension View {
    /// Hauteur, fond (mis en avant ou non) et séparateur d'une ligne, communs aux deux parties.
    func rowStyle(height: CGFloat, highlighted: Bool, theme: ResolvedTheme) -> some View {
        frame(height: height)
            .background(highlighted ? theme.primarySubtle : .clear)
            .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
    }
}
