import IdalgoKit
import SwiftUI

/// Écran « Briques » : un écran maison construit autour des briques du SDK et de l'état du Score
/// Center (`IdalgoScoreCenterModel`, direct simulé). Carrousel de cartes, classement « top 5 » de la
/// saison en cours de la Ligue 1, liste de l'app qui mêle ses propres lignes et les matchs du jour,
/// une ligne maison posée par `IdalgoComponents`, et le routeur (`.idalgoNavigation`) : une équipe
/// touchée est prise en charge par l'app, un match ouvre la feuille du SDK.
struct BlocksScreen: View {
    @StateObject private var model = IdalgoScoreCenterModel(sport: ScoreCenterScreen.football, client: FixtureTransport.client)
    @State private var theme = DemoLaunch.theme
    @State private var lastDestination: String?
    @State private var tappedTeam: String?

    var body: some View {
        List {
            Section {
                Text(lastDestination.map { "Routeur : \($0)" } ?? "Routeur : touchez un match ou une équipe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("router-log")
            }
            Section("Carrousel · IdalgoContestCard") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(model.day?.allContests ?? []) { contest in
                            IdalgoContestCard(contest: contest, timeZone: model.day?.timeZone).frame(width: 230)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets())
            }
            Section("Ligue 1 : top 5 et autour de Lens") {
                IdalgoStandingsView(
                    competition: "103",
                    highlight: ["22103"],
                    limit: 5,
                    around: 1,
                    showsSplitSelector: false,
                    showsHeader: false,
                    compact: true
                )
                .listRowInsets(EdgeInsets())
            }
            Section("Mes rubriques") {
                Label("À la une : la soirée de Ligue des champions", systemImage: "newspaper")
                Label("Vidéos : les buts du week-end", systemImage: "play.rectangle")
            }
            if let day = model.day {
                // Les matchs du jour, une section par compétition, dans la liste de l'app.
                IdalgoContests(day: day, status: model.status)
                if let first = day.competitions.first {
                    Section {
                        EmptyView()
                    } header: {
                        Text("Ligne maison · IdalgoComponents").font(.footnote).textCase(nil)
                    }
                    IdalgoScoreCenterSection(competition: first, timeZone: day.timeZone, showsStandingsButton: false)
                        .idalgoComponents(DemoComponents())
                }
            } else {
                Section { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .listStyle(.plain)
        .idalgoTheme(theme.theme)
        .idalgoNavigation { destination in
            switch destination {
            case let .team(id):
                lastDestination = "équipe \(id) → l'app"
                tappedTeam = id
                return .handled
            case let .contest(id):
                lastDestination = "match \(id) → feuille du SDK"
                return .default
            case let .standings(season, _):
                lastDestination = "classement \(season) → feuille du SDK"
                return .default
            }
        }
        .task { await model.run() }
        .navigationTitle("Briques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ThemeMenu(selection: $theme) }
        .alert("Équipe \(tappedTeam ?? "")", isPresented: Binding(get: { tappedTeam != nil }, set: { if !$0 { tappedTeam = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Le routeur de l'app a pris la main (.handled).")
        }
    }
}

/// Ligne maison : le match sur une ligne, heure ou minute en tête. Les autres parties restent celles
/// du SDK.
struct DemoComponents: IdalgoComponents {
    func contestRow(_ options: IdalgoContestRowOptions) -> some View {
        HStack(spacing: 10) {
            if case let .headToHead(duel) = options.contest {
                Text(Self.clock(duel, timeZone: options.timeZone))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(duel.status == .live ? .orange : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 52, alignment: .leading)
                Text(duel.home.competitor.name ?? "—")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(Self.score(duel))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(width: 56)
                Text(duel.away.competitor.name ?? "—")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private static func clock(_ duel: HeadToHeadContest, timeZone: TimeZone) -> String {
        if duel.status == .live { return duel.statusLabel ?? "Live" }
        guard let start = duel.startsAt else { return "—" }
        var style = Date.FormatStyle.dateTime.hour().minute()
        style.timeZone = timeZone
        return start.formatted(style)
    }

    private static func score(_ duel: HeadToHeadContest) -> String {
        guard let home = duel.home.score, let away = duel.away.score else { return "–" }
        return "\(Int(home)) – \(Int(away))"
    }
}
