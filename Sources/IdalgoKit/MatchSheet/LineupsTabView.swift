import SwiftUI

/// Les compositions : une équipe à la fois, son système, le terrain, l'entraîneur et les remplaçants.
struct LineupsTabView: View {
    let lineups: [Lineup]
    let marks: [String: PlayerMarks]

    @Environment(\.resolvedIdalgoTheme) private var theme
    @State private var selected = 0

    var body: some View {
        if lineups.allSatisfy({ $0.starters.isEmpty && $0.substitutes.isEmpty }) {
            MessageStateView(message: IdalgoStrings.noLineups)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                if lineups.count > 1 {
                    SegmentedPicker(
                        options: Array(lineups.indices),
                        selection: $selected,
                        label: { lineups[$0].competitor.name ?? "—" },
                        accessibilityLabel: IdalgoStrings.lineupTeam
                    )
                }
                if lineups.indices.contains(selected) {
                    lineup(lineups[selected])
                }
            }
            .padding(16)
        }
    }

    private func lineup(_ lineup: Lineup) -> some View {
        let (placed, unplaced) = PitchLayout.place(lineup)
        return VStack(alignment: .leading, spacing: 16) {
            if let formation = lineup.formation {
                Text(formation)
                    .font(theme.headingFont.font(.headline, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            if !placed.isEmpty {
                PitchView(players: placed, marks: marks, teamName: lineup.competitor.name ?? "—")
            }
            if !unplaced.isEmpty {
                playerList(IdalgoStrings.notOnPitch, unplaced)
            }
            if let coach = lineup.coach {
                section(IdalgoStrings.coach) {
                    PersonRow(name: coach.name ?? "—", detail: nil, photo: coach.photo, shirt: nil)
                }
            }
            if !lineup.substitutes.isEmpty {
                playerList(IdalgoStrings.substitutes, lineup.substitutes)
            }
        }
    }

    private func playerList(_ title: String, _ players: [LineupPlayer]) -> some View {
        section(title) {
            ForEach(players, id: \.person.id) { player in
                let mark = marks[player.person.id]
                PersonRow(
                    name: player.person.name ?? "—",
                    detail: mark?.inAt.map { "\($0.minute) – \($0.replaced)" } ?? player.positionLabel,
                    photo: nil,
                    shirt: player.shirt,
                    entered: mark?.inAt != nil
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(PitchLayout.accessibilityLabel(player, marks: mark))
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(theme.headingFont.font(.subheadline, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

/// Une personne en liste : numéro ou portrait, nom, précision (poste, entrée en jeu).
struct PersonRow: View {
    let name: String
    let detail: String?
    let photo: Logo?
    let shirt: Int?
    var entered = false

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var badge: CGFloat = 30

    var body: some View {
        HStack(spacing: 10) {
            if let shirt {
                Text(String(shirt))
                    .font(theme.bodyFont.font(.footnote, weight: .bold))
                    .monospacedDigit()
                    .frame(width: badge, height: badge)
                    .background(Circle().fill(theme.surface))
                    .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
            } else {
                PersonPhotoView(photo: photo, name: name, size: badge)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(theme.bodyFont.font(.subheadline))
                if let detail {
                    HStack(spacing: 4) {
                        if entered {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.positive)
                        }
                        Text(detail)
                            .font(theme.bodyFont.font(.caption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Portrait rond d'une personne ; ses initiales s'il manque.
struct PersonPhotoView: View {
    let photo: Logo?
    let name: String
    let size: CGFloat

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        Group {
            if let photo {
                CachedImage(url: photo.large.url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initials
                }
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var initials: some View {
        ZStack {
            theme.surface
            Text(TeamLogoView.initials(of: name))
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }
}
