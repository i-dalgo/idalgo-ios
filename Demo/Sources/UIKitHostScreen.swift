import IdalgoKit
import SwiftUI
import UIKit

/// Écran d'une app UIKit : une `UINavigationController` dont la racine est un `UIHostingController`
/// qui montre le Score Center, sans `NavigationStack`. Un match touché pousse la feuille de match du
/// SDK dans cette `UINavigationController` (direct simulé, sans réseau).
struct UIKitHostScreen: UIViewControllerRepresentable {
    /// Ferme l'écran ; `nil` quand il est la racine de l'app (argument `-uikitHost`).
    var onClose: (() -> Void)?

    func makeUIViewController(context: Context) -> UINavigationController {
        let scoreCenter = UIHostingController(rootView: ScrollView {
            IdalgoScoreCenterView(sport: ScoreCenterScreen.football, client: FixtureTransport.client)
        })
        scoreCenter.title = "Hôte UIKit"
        scoreCenter.navigationItem.largeTitleDisplayMode = .never
        if onClose != nil {
            scoreCenter.navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .close,
                primaryAction: UIAction { _ in context.coordinator.onClose?() }
            )
        }
        return UINavigationController(rootViewController: scoreCenter)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        context.coordinator.onClose = onClose
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    final class Coordinator {
        var onClose: (() -> Void)?

        init(onClose: (() -> Void)?) {
            self.onClose = onClose
        }
    }
}

/// Les contrôleurs UIKit du SDK : `IdalgoMatchSheetViewController` à la racine d'une
/// `UINavigationController` (direct simulé), avec un routeur qui reçoit les équipes touchées et
/// pousse le classement en `IdalgoStandingsViewController`.
struct UIKitControllersScreen: UIViewControllerRepresentable {
    var onClose: (() -> Void)?

    func makeUIViewController(context: Context) -> UINavigationController {
        let sheet = IdalgoMatchSheetViewController(
            contest: DemoMatch.liveDemoContest,
            initialTab: .preview,
            client: FixtureTransport.client
        )
        let navigation = UINavigationController(rootViewController: sheet)
        sheet.navigation = { [weak navigation] destination in
            guard case .team = destination else { return .default }
            // L'app répond elle-même : le classement de la Premier League, l'équipe mise en avant.
            if case let .team(id) = destination {
                let standings = IdalgoStandingsViewController(competition: "503", highlight: [id])
                navigation?.pushViewController(standings, animated: true)
            }
            return .handled
        }
        if onClose != nil {
            sheet.navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .close,
                primaryAction: UIAction { _ in context.coordinator.onClose?() }
            )
        }
        return navigation
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        context.coordinator.onClose = onClose
    }

    func makeCoordinator() -> UIKitHostScreen.Coordinator {
        UIKitHostScreen.Coordinator(onClose: onClose)
    }
}
