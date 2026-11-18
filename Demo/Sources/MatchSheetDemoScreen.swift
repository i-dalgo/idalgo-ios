import IdalgoKit
import SwiftUI

/// Écran de feuille de match : le composant du SDK, un choix de thème et l'équipe touchée.
struct MatchSheetDemoScreen: View {
    let contest: String
    let tab: MatchSheetTab?
    let liveDemo: Bool

    @State private var theme = DemoLaunch.theme
    @State private var tappedTeam: TeamCompetitor?

    var body: some View {
        ScrollView {
            IdalgoMatchSheetView(
                contest: contest,
                initialTab: tab,
                client: liveDemo ? FixtureTransport.client : nil
            ) { team in
                tappedTeam = team
            }
            .idalgoTheme(theme.theme)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(liveDemo ? "Direct simulé" : "Feuille de match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ThemeMenu(selection: $theme) }
        .alert(tappedTeam?.name ?? "", isPresented: Binding(get: { tappedTeam != nil }, set: { if !$0 { tappedTeam = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Équipe touchée (id \(tappedTeam?.id ?? "")). L'app hôte décide de la suite.")
        }
    }
}
