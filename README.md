# IdalgoKit — le SDK iOS d'iDalgo

Les widgets sportifs d'iDalgo **en natif SwiftUI** dans votre application, et les données de l'API
pour construire vos propres écrans. Classement, Score Center et feuille de match, en direct,
habillés par votre thème.

- **Natif** : vos écrans suivent le système (taille du texte, mode sombre, VoiceOver), pas de
  webview.
- **Direct géré pour vous** : les scores se mettent à jour seuls pendant les matchs, au rythme
  indiqué par l'API, en pause quand l'application passe en arrière-plan.
- **Adaptable** : un widget complet en une ligne, des briques à assembler (carte de match, ligne,
  classement réduit…), ou les données seules.
- **Léger** : aucune dépendance tierce, aucun suivi, aucune donnée personnelle collectée.

Documentation complète : **[doc.idalgo.live/mobile](https://doc.idalgo.live/mobile/)**

> **Avant-première `0.9.x`** : l'API du SDK peut encore changer d'une version mineure à l'autre ;
> chaque changement est annoncé dans le [journal](https://doc.idalgo.live/journal/).

## Prérequis

- iOS 16 ou plus récent, Xcode 16 ou plus récent (Swift 6).
- Une **clé publique iDalgo** (`idl_pk_…`), remise par votre contact iDalgo. Elle identifie votre
  média et ouvre l'accès aux données de votre contrat.

## Installation

Dans Xcode : **File → Add Package Dependencies…**, saisissez l'adresse de ce dépôt, choisissez la
version `0.9.0` (règle « Up to Next Minor Version »), puis ajoutez la bibliothèque **`IdalgoKit`** à
votre cible.

```
https://github.com/i-dalgo/idalgo-ios
```

Ou dans un `Package.swift` :

```swift
dependencies: [
    .package(url: "https://github.com/i-dalgo/idalgo-ios", .upToNextMinor(from: "0.9.0")),
],
targets: [
    .target(name: "MonApp", dependencies: [.product(name: "IdalgoKit", package: "idalgo-ios")]),
]
```

## Démarrer en deux étapes

**1. Configurez le SDK une fois**, au lancement de l'application :

```swift
import IdalgoKit

@main
struct MonApp: App {
    init() {
        Idalgo.configure(IdalgoConfiguration(apiKey: "idl_pk_…"))
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

**2. Posez un widget** :

```swift
NavigationStack {
    ScrollView {
        IdalgoScoreCenterView(sport: "102") // football : les matchs du jour, en direct
    }
}
```

Toucher un match ouvre sa feuille de match. Pour ouvrir votre propre écran à la place, passez
`onContestTap`, ou décidez de toute la navigation avec `.idalgoNavigation { … }`.

N'utilisez jamais votre clé secrète `idl_sk_…` dans une application : le SDK la refuse.

## Widgets

| Widget           | Code                                        | Documentation                                                        |
| ---------------- | ------------------------------------------- | -------------------------------------------------------------------- |
| Classement       | `IdalgoStandingsView(competition: "103")`   | [Classement](https://doc.idalgo.live/mobile/classement/)             |
| Score Center     | `IdalgoScoreCenterView(sport: "102")`       | [Score Center](https://doc.idalgo.live/mobile/score-center/)         |
| Feuille de match | `IdalgoMatchSheetView(contest: "54732603")` | [Feuille de match](https://doc.idalgo.live/mobile/feuille-de-match/) |

Chaque widget prend la hauteur de son contenu : placez-le dans une `ScrollView`. Dans une
application UIKit, utilisez `IdalgoMatchSheetViewController` / `IdalgoStandingsViewController`, ou
hébergez la vue dans un `UIHostingController`.

## Votre thème

Les widgets reprennent le thème de vos widgets web (couleurs, polices, arrondis, mode sombre). iDalgo
vous le transmet au format JSON :

```swift
let theme = try IdalgoTheme(json: Data(themeJSON.utf8))
Idalgo.configure(IdalgoConfiguration(apiKey: "idl_pk_…", theme: theme))
```

Voir [Installer et configurer](https://doc.idalgo.live/mobile/installation/).

## Aller plus loin

- **[Personnaliser](https://doc.idalgo.live/mobile/personnaliser/)** : options des widgets
  (masquer le filtre, choisir les onglets, top N d'un classement), briques à assembler (carte de
  match pour un carrousel, matchs dans votre propre `List`), parties remplaçables, jetons
  d'apparence, routeur de navigation.
- **[Vos propres écrans](https://doc.idalgo.live/mobile/donnees/)** : `Idalgo.client` donne les
  données décodées ; `matchSheetUpdates` et `scoreCenterUpdates` les tiennent à jour pendant le
  direct :

  ```swift
  for try await sheet in Idalgo.client.matchSheetUpdates(contest: "54732603") {
      self.sheet = sheet
  }
  ```

## Confidentialité

Le paquet inclut son manifeste de confidentialité (`PrivacyInfo.xcprivacy`) : aucun suivi, aucune
donnée collectée. Chaque appel à l'API envoie votre clé publique, l'identifiant de votre application
(bundle id) et la version du SDK, pour le suivi de consommation de votre contrat.

## Application de démo

Le dossier `Demo/` contient une application qui ouvre chaque widget sur les données réelles. Pour la
construire et la lancer, voir [DEVELOPPEMENT.md](DEVELOPPEMENT.md).

## Support et licence

- Questions, accès, clé : votre contact iDalgo.
- Un problème avec le SDK : ouvrez un ticket sur ce dépôt.
- Licence : propriétaire, usage réservé aux clients iDalgo sous contrat (voir [LICENSE](LICENSE)).
