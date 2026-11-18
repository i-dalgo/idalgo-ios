import IdalgoKit
import SwiftUI

/// Écran du Score Center (football) : le composant du SDK et un choix de thème. Un match touché
/// ouvre la feuille de match du SDK (navigation par défaut, sans `onContestTap`).
struct ScoreCenterScreen: View {
    /// Football (`/v1/sports`).
    static let football = "102"

    let date: String?
    let liveDemo: Bool

    @State private var theme = DemoLaunch.theme

    var body: some View {
        ScrollView {
            IdalgoScoreCenterView(
                sport: Self.football,
                date: date,
                client: liveDemo ? FixtureTransport.client : nil
            )
            .idalgoTheme(theme.theme)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(liveDemo ? "Direct simulé" : "Score Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ThemeMenu(selection: $theme) }
    }
}
