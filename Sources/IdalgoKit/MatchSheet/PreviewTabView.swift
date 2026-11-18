import SwiftUI

/// L'avant-match : forme, classement à la date du match, joueurs clés, confrontations.
struct PreviewTabView: View {
    let sheet: MatchSheet
    let timeZone: TimeZone
    let onTeamTap: ((TeamCompetitor) -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme

    private var homeId: String? { sheet.contest.home.competitor.id }
    private var awayId: String? { sheet.contest.away.competitor.id }

    var body: some View {
        let keyLines = sheet.keyPlayers.map(KeyPlayerLine.lines) ?? []
        let hasForm = !sheet.form.home.isEmpty || !sheet.form.away.isEmpty
        if !hasForm, sheet.standings.overall == nil, keyLines.isEmpty, sheet.headToHead == nil {
            MessageStateView(message: IdalgoStrings.noPreview)
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if hasForm { formSection.padding(.horizontal, 16) }
                if sheet.standings.overall != nil {
                    section(IdalgoStrings.standings) {
                        IdalgoStandingsView(
                            standings: sheet.standings.bySplit,
                            highlight: [homeId, awayId].compactMap { $0 },
                            showsHeader: false,
                            onTeamTap: onTeamTap
                        )
                    }
                }
                if !keyLines.isEmpty { keyPlayers(keyLines).padding(.horizontal, 16) }
                if let summary = sheet.headToHead { headToHead(summary) }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: Forme

    private var formSection: some View {
        section(IdalgoStrings.form, padded: false) {
            formRow(sheet.contest.home.competitor, sheet.form.home)
            formRow(sheet.contest.away.competitor, sheet.form.away)
        }
    }

    private func formRow(_ team: ContestCompetitor, _ entries: [FormEntry]) -> some View {
        HStack(spacing: 8) {
            TeamLogoView(logo: team.image, name: team.name, size: 22)
            Text(team.name ?? "—")
                .font(theme.bodyFont.font(.subheadline, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                ForEach(entries.map(FormChip.init)) { chip in
                    FormChipView(chip: chip)
                }
            }
        }
    }

    // MARK: Joueurs clés

    private func keyPlayers(_ lines: [KeyPlayerLine]) -> some View {
        section(IdalgoStrings.keyPlayers, padded: false) {
            ForEach(lines) { line in
                VStack(spacing: 6) {
                    Text(line.label.uppercased())
                        .font(theme.bodyFont.font(.caption2, weight: .bold))
                        .foregroundStyle(theme.textSecondary)
                    HStack(alignment: .top) {
                        keyPlayer(line.home)
                        keyPlayer(line.away)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: theme.radius.m).fill(theme.surface))
            }
        }
    }

    @ViewBuilder
    private func keyPlayer(_ player: KeyPlayer?) -> some View {
        VStack(spacing: 4) {
            if let player {
                PersonPhotoView(photo: player.photo, name: player.name, size: 48)
                Text(player.name)
                    .font(theme.bodyFont.font(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(player.detail)
                    .font(theme.bodyFont.font(.caption))
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text("—").foregroundStyle(theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Confrontations

    @ViewBuilder
    private func headToHead(_ summary: HeadToHeadSummary) -> some View {
        section(IdalgoStrings.headToHead) {
            if summary.contestCount > 0, let balance = HeadToHeadBalance(summary, homeId: homeId) {
                HeadToHeadBar(balance: balance).padding(.horizontal, 16)
                HStack(spacing: 8) {
                    figure(balance.averageGoals, IdalgoStrings.averageGoals)
                    figure(balance.scoreless, IdalgoStrings.scoreless)
                    figure(balance.frequentScore, IdalgoStrings.frequentScore)
                }
                .padding(.horizontal, 16)
            } else {
                Text(IdalgoStrings.firstMeeting)
                    .font(theme.bodyFont.font(.subheadline))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 16)
            }
        }
        let meetings = summary.last.compactMap { ScoreCenterPresentation.row($0, timeZone: timeZone) }
        if !meetings.isEmpty {
            section(IdalgoStrings.lastMeetings) {
                VStack(spacing: 0) {
                    ForEach(meetings) { row in
                        ContestRowView(row: row, caption: row.contest.startsAt.map { Self.shortDate($0, timeZone: timeZone) })
                            .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
                    }
                }
            }
        }
    }

    /// « 12/03/25 » : date d'une confrontation passée.
    static func shortDate(_ date: Date, timeZone: TimeZone) -> String {
        let day = ScoreCenterFormat.calendarDate(date, timeZone: timeZone).split(separator: "-")
        return "\(day[2])/\(day[1])/\(day[0].suffix(2))"
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(theme.headingFont.font(.headline, weight: .bold))
            Text(label)
                .font(theme.bodyFont.font(.caption2))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: theme.radius.s).fill(theme.surface))
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(_ title: String, padded: Bool = true, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(theme.headingFont.font(.headline, weight: .bold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, padded ? 16 : 0)
            content()
        }
    }
}

/// Pastille de forme : V en vert, N en gris, D en rouge.
private struct FormChipView: View {
    let chip: FormChip

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 22

    var body: some View {
        Text(chip.letter)
            .font(theme.bodyFont.font(.caption2, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: theme.radius.xs).fill(color))
            .accessibilityLabel(chip.accessibilityLabel)
    }

    private var color: Color {
        switch chip.result {
        case .win: theme.win
        case .draw: theme.draw
        case .loss: theme.loss
        }
    }
}

/// Barre du bilan : victoires du domicile, nuls, victoires de l'extérieur, en proportion.
private struct HeadToHeadBar: View {
    let balance: HeadToHeadBalance

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        let total = max(balance.results.map(\.value).reduce(0, +), 1)
        VStack(spacing: 6) {
            HStack {
                ForEach(balance.results) { segment in
                    VStack(spacing: 0) {
                        Text(String(segment.value)).font(theme.headingFont.font(.title3, weight: .bold))
                        Text(segment.label)
                            .font(theme.bodyFont.font(.caption2))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(Array(balance.results.enumerated()), id: \.element.id) { index, segment in
                        color(index).frame(width: max(proxy.size.width * CGFloat(segment.value) / CGFloat(total) - 2, 0))
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(balance.results.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }

    private func color(_ index: Int) -> Color {
        switch index {
        case 0: theme.primary
        case 1: theme.border
        default: theme.secondary.opacity(0.55)
        }
    }
}
