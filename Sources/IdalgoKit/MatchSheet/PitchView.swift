import SwiftUI

/// Le terrain d'une composition : lignes dessinées, titulaires placés par leurs coordonnées (le
/// gardien en haut), numéro, nom et ce qui leur est arrivé (but, carton, sortie).
struct PitchView: View {
    let players: [PlacedPlayer]
    let marks: [String: PlayerMarks]
    let teamName: String

    @Environment(\.resolvedIdalgoTheme) private var theme

    /// Proportions du terrain dessiné (largeur / longueur), comme sur le web.
    private static let ratio: CGFloat = 100 / 146
    /// Largeur au plus : le terrain entier tient à l'écran d'un téléphone sous les onglets.
    private static let maxWidth: CGFloat = 330

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 18
            let field = CGRect(x: inset, y: inset, width: proxy.size.width - inset * 2, height: proxy.size.height - inset * 2)
            ZStack(alignment: .topLeading) {
                PitchLines()
                    .stroke(theme.border, lineWidth: 1.2)
                    .frame(width: field.width, height: field.height)
                    .offset(x: field.minX, y: field.minY)
                ForEach(players) { placed in
                    PitchPlayerView(player: placed.player, marks: marks[placed.player.person.id])
                        .position(x: field.minX + field.width * placed.x, y: field.minY + field.height * placed.y)
                }
            }
        }
        .aspectRatio(Self.ratio, contentMode: .fit)
        .background(RoundedRectangle(cornerRadius: theme.radius.m).fill(theme.surface))
        .frame(maxWidth: Self.maxWidth)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Composition de \(teamName) sur le terrain")
    }
}

/// Les lignes d'un terrain, dans un repère de 100 × 146 (le gardien du haut défend le but du haut).
private struct PitchLines: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100
        let sy = rect.height / 146
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * sx, y: rect.minY + y * sy, width: w * sx, height: h * sy)
        }
        var path = Path()
        path.addRoundedRect(in: r(0, 0, 100, 146), cornerSize: CGSize(width: 2, height: 2))
        path.addRect(r(21, 0, 58, 24))
        path.addRect(r(35, 0, 30, 9))
        path.addRect(r(21, 122, 58, 24))
        path.addRect(r(35, 137, 30, 9))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addEllipse(in: CGRect(x: rect.midX - 13 * sx, y: rect.midY - 13 * sx, width: 26 * sx, height: 26 * sx))
        // Arcs des surfaces : chacun part de sa première extrémité, sans trait depuis le point précédent.
        let radius = 9 * sx
        for (centreY, start) in [(24 * sy, 0.0), (122 * sy, 180.0)] {
            let centre = CGPoint(x: rect.midX, y: rect.minY + centreY)
            let angle = Angle.degrees(start).radians
            path.move(to: CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle)))
            path.addArc(center: centre, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + 180), clockwise: false)
        }
        return path
    }
}

/// Un joueur sur le terrain : pastille au numéro, nom dessous, badges (but, carton, sortie, capitaine).
private struct PitchPlayerView: View {
    let player: LineupPlayer
    let marks: PlayerMarks?

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .footnote) private var size: CGFloat = 32

    var body: some View {
        VStack(spacing: 3) {
            Text(player.shirt.map(String.init) ?? "")
                .font(theme.bodyFont.font(.footnote, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(theme.onPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(theme.primary))
                .overlay(alignment: .topTrailing) { card.offset(x: 4, y: -2) }
                .overlay(alignment: .topLeading) { goals.offset(x: -6, y: -4) }
                .overlay(alignment: .bottomTrailing) { substituted.offset(x: 6, y: 2) }
                .overlay(alignment: .bottomLeading) { captain.offset(x: -5, y: 2) }
            Text(MatchSheetFormat.lastName(player.person.name))
                .font(theme.bodyFont.font(.caption2, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: 62)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PitchLayout.accessibilityLabel(player, marks: marks))
    }

    @ViewBuilder
    private var card: some View {
        if marks?.redCard == true {
            RoundedRectangle(cornerRadius: 1.5).fill(theme.redCard).frame(width: 8, height: 11)
        } else if (marks?.yellowCards ?? 0) > 0 {
            RoundedRectangle(cornerRadius: 1.5).fill(theme.yellowCard).frame(width: 8, height: 11)
        }
    }

    @ViewBuilder
    private var goals: some View {
        if let count = marks.map({ $0.goals + $0.ownGoals }), count > 0 {
            HStack(spacing: 1) {
                Image(systemName: "soccerball").font(.system(size: 9, weight: .bold))
                if count > 1 { Text(String(count)).font(.system(size: 9, weight: .bold)) }
            }
            .padding(2)
            .foregroundStyle(marks?.ownGoals ?? 0 > 0 ? theme.negative : theme.text)
            .background(Capsule().fill(theme.background))
        }
    }

    @ViewBuilder
    private var substituted: some View {
        if marks?.outAt != nil {
            Image(systemName: "arrow.down")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 14, height: 14)
                .background(Circle().fill(theme.negative))
        }
    }

    @ViewBuilder
    private var captain: some View {
        if player.captain {
            Text("C")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(theme.primary)
                .frame(width: 13, height: 13)
                .background(Circle().fill(theme.background))
                .overlay(Circle().strokeBorder(theme.primary, lineWidth: 1))
        }
    }
}
