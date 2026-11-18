import IdalgoKit
import SwiftUI

/// Écran de la démo.
enum DemoRoute: Hashable {
    case standings(DemoCompetition)
    /// Score Center du football ; `liveDemo` : servi par les fixtures, en direct simulé.
    case scoreCenter(date: String?, liveDemo: Bool)
    /// Feuille de match ; `liveDemo` : servie par les fixtures, en direct simulé.
    case matchSheet(contest: String, tab: MatchSheetTab?, liveDemo: Bool)
    /// Écran maison construit avec les briques, l'état et le routeur.
    case blocks
}

/// Accueil : les classements de quelques compétitions et le Score Center.
struct DemoHomeView: View {
    @State private var path: [DemoRoute]
    @State private var showsUIKitHost = false
    @State private var showsUIKitSheet = false

    init(initialRoute: DemoRoute?) {
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Personnaliser") {
                    row("Briques", detail: "Cartes, top 5, liste mixte, ligne maison, routeur", route: .blocks)
                    Button { showsUIKitSheet = true } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contrôleurs UIKit").font(.headline)
                            Text("IdalgoMatchSheetViewController poussé, routeur").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                }
                Section("Score Center") {
                    row("Football", detail: "Matchs du jour, en direct", route: .scoreCenter(date: nil, liveDemo: false))
                    row("Direct simulé", detail: "Réponses enregistrées, sans réseau", route: .scoreCenter(date: nil, liveDemo: true))
                    Button { showsUIKitHost = true } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hôte UIKit").font(.headline)
                            Text("UINavigationController, sans NavigationStack").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.primary)
                }
                Section("Feuille de match") {
                    ForEach(DemoMatch.all) { match in
                        row(match.title, detail: match.detail, route: .matchSheet(contest: match.contest, tab: nil, liveDemo: false))
                    }
                    row("Direct simulé", detail: "Arsenal – Leeds à la 67e, sans réseau", route: .matchSheet(contest: DemoMatch.liveDemoContest, tab: nil, liveDemo: true))
                }
                Section("Classements") {
                    ForEach(DemoCompetition.all) { competition in
                        row(competition.name, detail: competition.detail, route: .standings(competition))
                    }
                }
            }
            .navigationTitle("iDalgo")
            .fullScreenCover(isPresented: $showsUIKitHost) {
                UIKitHostScreen { showsUIKitHost = false }.ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showsUIKitSheet) {
                UIKitControllersScreen { showsUIKitSheet = false }.ignoresSafeArea()
            }
            .navigationDestination(for: DemoRoute.self) { route in
                switch route {
                case let .standings(competition): StandingsScreen(competition: competition)
                case let .scoreCenter(date, liveDemo): ScoreCenterScreen(date: date, liveDemo: liveDemo)
                case let .matchSheet(contest, tab, liveDemo): MatchSheetDemoScreen(contest: contest, tab: tab, liveDemo: liveDemo)
                case .blocks: BlocksScreen()
                }
            }
        }
    }

    private func row(_ title: String, detail: String, route: DemoRoute) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

/// Menu de la barre : thème posé sur le composant (`.idalgoTheme`).
struct ThemeMenu: View {
    @Binding var selection: DemoTheme

    var body: some View {
        Menu {
            Picker("Thème", selection: $selection) {
                ForEach(DemoTheme.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Image(systemName: "paintpalette")
        }
        .accessibilityLabel("Thème")
    }
}
