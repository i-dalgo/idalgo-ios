import IdalgoKit
import SwiftUI

/// Écran de classement : le composant du SDK, un choix de thème et l'équipe touchée.
struct StandingsScreen: View {
    let competition: DemoCompetition

    @State private var theme = DemoLaunch.theme
    @State private var tappedTeam: TeamCompetitor?

    var body: some View {
        ScrollView {
            IdalgoStandingsView(season: competition.season, highlight: competition.highlight) { team in
                tappedTeam = team
            }
            .idalgoTheme(theme.theme)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(competition.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ThemeMenu(selection: $theme) }
        .alert(tappedTeam?.name ?? "", isPresented: Binding(get: { tappedTeam != nil }, set: { if !$0 { tappedTeam = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Équipe touchée (id \(tappedTeam?.id ?? "")). L'app hôte décide de la suite.")
        }
    }
}
