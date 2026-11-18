import IdalgoKit
import SwiftUI

/// Une compétition de la démo : sa saison en cours et les équipes mises en avant.
struct DemoCompetition: Identifiable, Hashable {
    let name: String
    let detail: String
    let season: String
    let highlight: [String]

    var id: String { season }

    static let all = [
        DemoCompetition(name: "Ligue 1", detail: "Classement aux points", season: "374703", highlight: ["24803"]),
        DemoCompetition(name: "NBA", detail: "Pourcentage de victoires", season: "46602", highlight: []),
        DemoCompetition(name: "Ligue des Nations", detail: "14 poules", season: "369003", highlight: ["118403"]),
    ]
}

/// Thèmes proposés par la démo, posés sur le composant (`.idalgoTheme`).
enum DemoTheme: String, CaseIterable, Identifiable {
    case idalgo = "iDalgo"
    case neutral = "Neutre"
    case media = "Exemple de média"
    case tokens = "Média compact"

    var id: String { rawValue }

    var theme: IdalgoTheme {
        switch self {
        case .idalgo: .default
        case .neutral: .neutral
        case .media: Self.mediaTheme
        case .tokens: Self.tokensTheme
        }
    }

    /// Thème d'un média tel qu'il arrive de sa fiche (`ThemeConfig` en JSON), mode automatique.
    private static let mediaTheme: IdalgoTheme = {
        let json = """
        {
          "name": "Exemple de média",
          "colors": { "primary": "#b3122e", "secondary": "#5c4a4f", "background": "#fffdf9", "text": "#1f1416" },
          "fonts": { "heading": "Georgia, serif", "body": "Georgia, serif" },
          "radius": { "xs": "8px", "s": "14px", "m": "20px", "l": "28px" },
          "mode": "auto"
        }
        """
        return (try? IdalgoTheme(json: Data(json.utf8))) ?? .default
    }()

    /// Les jetons d'apparence : densité compacte, texte un peu plus petit, fond transparent, couleur
    /// du direct en orange (JSON), et marque en couleur native dynamique (indigo du système).
    private static let tokensTheme: IdalgoTheme = {
        let json = """
        {
          "name": "Média compact",
          "colors": { "primary": "#3f3fbf", "secondary": "#4b4b6b", "background": "#ffffff", "text": "#1c1c28" },
          "fonts": { "heading": "Avenir Next", "body": "Avenir Next" },
          "mode": "auto",
          "statusColors": { "live": "#e8590c", "win": "#2b8a3e" },
          "fontScale": 0.95,
          "density": "compact",
          "background": "transparent"
        }
        """
        let theme = (try? IdalgoTheme(json: Data(json.utf8))) ?? .default
        return theme.with(.primary, uiColor: .systemIndigo)
    }()
}

/// Un match de la démo.
struct DemoMatch: Identifiable {
    let title: String
    let detail: String
    let contest: String

    var id: String { contest }

    /// Match du direct simulé : celui des fixtures de la feuille de match.
    static let liveDemoContest = "54732603"

    static let all = [
        DemoMatch(title: "Arsenal – Leeds United", detail: "Premier League, terminé 2-1", contest: "54732603"),
        DemoMatch(title: "Danemark – Norvège", detail: "Ligue des Nations, à venir", contest: "54436503"),
    ]
}
