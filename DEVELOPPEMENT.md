# IdalgoKit (iOS) — développement

SDK iOS natif d'iDalgo : la couche de données de l'API `/v1`, le thème des médias et des composants
SwiftUI. Jalon 1 : fondations et composant **Classement** ; jalon 2 : **Score Center** ; jalon 3 :
**Feuille de match** avec direct ; lot 2 (IDA-221) : **personnalisation** (briques, états, options,
composants remplaçables, jetons d'apparence, routeur). Version 0.9.0 (avant-première ; 1.0.0 au premier client),
lue dans `mobile/VERSION`, iOS 16+, Swift 6, sans dépendance tierce.

## Structure

```
Package.swift            # paquet Swift « IdalgoKit » (iOS 16, macOS 13 pour `swift test`)
Sources/IdalgoCore/      # Foundation seule, testable sur le Mac
  Configuration/         # Idalgo.configure(…), IdalgoConfiguration
  Client/                # IdalgoClient, transport, cache max-age / ETag, nouvelles tentatives, erreurs
  Models/                # contrat public (miroir de packages/shared-types/src/v1)
  Theme/                 # IdalgoTheme (forme ThemeConfig), déductions des couleurs et du mode sombre
  Live/                  # direct : quand relire (LiveSchedule), flux suivi au rythme de pollAfter (LiveStream)
  Format/                # libellés français, formatage, classement et Score Center prêts à afficher
  MatchSheet/            # feuille de match : fil des actions, buteurs, terrain, avant-match
  PrivacyInfo.xcprivacy  # manifeste de confidentialité : ni suivi, ni donnée collectée
Sources/IdalgoKit/       # vues SwiftUI ; `import IdalgoKit` réexporte IdalgoCore
  State/                 # IdalgoScoreCenterModel, IdalgoMatchSheetModel : lecture + direct, publics
  Blocks/                # briques sans état : ligne, carte, en-tête, tableau, rubriques de la feuille
  Components/            # IdalgoComponents (parties remplaçables), états vide / erreur / chargement
  Navigation/            # routeur (.idalgoNavigation, IdalgoDestination), écrans ouverts par le SDK
  UIKit/                 # IdalgoMatchSheetViewController, IdalgoStandingsViewController
Tests/IdalgoCoreTests/   # Swift Testing, sur les réponses réelles de ../fixtures (ou Tests/Fixtures)
Tests/IdalgoKitTests/    # navigation et routeur, thème résolu et jetons, états publics, animations
Demo/                    # app de démo (projet généré par XcodeGen depuis project.yml)
  UITests/               # tests d'interface : feuille Classement, match touché → feuille (SwiftUI
                         # et UIKit), terrain, écran « Briques » (routeur, liste mixte, ligne
                         # maison), contrôleurs UIKit
```

**API publique** : la configuration (`Idalgo`, `IdalgoConfiguration`), le client et ses méthodes
(dont les flux `…Updates`), le transport, les modèles du contrat (`Hashable`, `Sendable`), les
erreurs, le thème et ses jetons, les trois vues et leurs options, les deux états
(`IdalgoScoreCenterModel`, `IdalgoMatchSheetModel`, `IdalgoPhase`), les briques (`IdalgoContestRow`,
`IdalgoContestCard`, `IdalgoMatchHeader`, `IdalgoStandingsTable`, `IdalgoActionsTimeline`,
`IdalgoLineupPitch`, `IdalgoPreMatch`, `IdalgoContests`, `IdalgoScoreCenterSection`),
`IdalgoComponents` et ses options, le routeur (`IdalgoDestination`, `IdalgoNavigationResult`), les
deux contrôleurs UIKit, `.idalgoTheme(_:)`, `.idalgoComponents(_:)`, `.idalgoNavigation(_:)` et
`.idalgoContestPresentation(_:)`. Les
libellés, le formatage et la présentation (`Format/`, `MatchSheet/`, `LiveSchedule`) sont en
accès `package` : partagés par les deux cibles, hors de l'API publique, ils peuvent changer sans
nouvelle version majeure. Les listes ouvertes du contrat (statut d'un contest, type et famille
d'une action, code d'un sport, format d'une phase, code d'erreur `IdalgoError.Code`) sont des
types ouverts (`RawRepresentable`) : une valeur nouvelle se lit sans casser l'app ; `kind` et
`type` restent des énumérations fermées (une valeur nouvelle viendrait avec une nouvelle version
du contrat).

## Intégration

Dans Xcode : _File › Add Package Dependencies…_ (ou dépendance locale vers `mobile/ios`), produit
`IdalgoKit`. Le produit `IdalgoCore` seul suffit pour des écrans maison sans les composants.

```swift
import IdalgoKit

// Au démarrage de l'app. La clé est facultative tant que l'API est ouverte.
Idalgo.configure(IdalgoConfiguration(apiKey: "idl_pk_…", lang: "fr", theme: .default))

// Composant natif : hauteur naturelle, à placer dans une ScrollView.
ScrollView {
    IdalgoStandingsView(season: "374703", highlight: ["24803"]) { team in
        // Équipe touchée : l'app décide de la suite.
    }
    .idalgoTheme(monTheme) // facultatif : remplace le thème global pour cette vue
}

// Score Center : matchs du jour d'un sport (102 : football), direct relu pendant les matchs.
// Un match touché ouvre la feuille de match du SDK ; `onContestTap` remplace ce comportement.
ScrollView {
    IdalgoScoreCenterView(sport: "102", competitions: ["103"])
}

// Feuille de match : en-tête, Infos / Actions / Compos / Avant-match, direct pendant le match.
ScrollView {
    IdalgoMatchSheetView(contest: "54732603", initialTab: .lineups)
}

// Classement déjà lu (non relu sur l'API), compact, deux équipes mises en avant.
IdalgoStandingsView(standings: sheet.standings.bySplit, highlight: ["7703", "8403"], compact: true)

// Données seules, pour un écran maison.
let standings = try await Idalgo.client.standings(season: "374703", split: .home)
let day = try await Idalgo.client.scoreCenter(sport: "102", date: "2026-11-08")
let live = try await Idalgo.client.scoreCenterLive(sport: "102", date: day.date)
let updated = day.applying(live.data) // live.pollAfter : secondes avant de relire, nil = arrêter
let sheet = try await Idalgo.client.matchSheet(contest: "54732603")

// Direct géré : la feuille, puis la feuille à jour à chaque lecture, jusqu'à la fin du match.
for try await sheet in Idalgo.client.matchSheetUpdates(contest: "54732603") { show(sheet) }

// Options, et entrées mises à jour sur place (changer `date` relit le jour).
IdalgoScoreCenterView(sport: "102", date: day, status: .live, showsStatusFilter: false)
IdalgoMatchSheetView(contest: "54732603", tabs: [.actions, .lineups], showsHeader: false)
IdalgoStandingsView(competition: "103", highlight: ["22103"], limit: 5, around: 1, compact: true)

// Écran maison : l'état public et les briques, dans une List de l'app.
@StateObject var model = IdalgoScoreCenterModel(sport: "102")
List {
    MaRubrique()
    if let day = model.day { IdalgoContests(day: day, status: model.status) }
}
.task { await model.run() }
.idalgoComponents(MesComposants())        // ligne, bandeau, états vide / erreur / chargement
.idalgoNavigation { destination in        // .contest, .team, .standings
    if case let .team(id) = destination { router.showTeam(id); return .handled }
    return .default                       // le SDK ouvre sa feuille de match ou son classement
}
```

- **Thème** : `IdalgoTheme(json:)` décode le thème d'un média (`meta.client.theme`, forme
  `ThemeConfig`). Les couleurs absentes et le mode sombre sont déduits avec les mêmes règles que
  les widgets web (`apps/ui-kit/src/utils/theme.ts`). Mode `auto` : suit l'appareil. Le thème par
  défaut (`.default`, couleurs d'idalgo.fr) est en `auto` ; un thème JSON sans `mode` reste clair.
- **Polices** : la première famille de la pile installée dans l'app, sinon la police système.
- **Jetons d'apparence** (facultatifs dans le JSON, défauts du design system) : `statusColors`
  (`live`, `win`, `draw`, `loss`, `yellowCard`, `redCard`, valables dans les deux modes),
  `fontScale` (0,5 à 2, la taille de texte de l'appareil s'applique en plus), `density`
  (`regular` / `compact` : lignes de match 56 → 44, de classement 44 → 36, marges réduites d'un
  quart), `background` (`theme` / `transparent`). Une valeur illisible garde le défaut. Couleurs
  natives : `theme.with(.primary, Color(…))`, `theme.with(.live, uiColor: …)` (dynamiques et
  couleurs d'assets comprises, prioritaires sur le texte, jamais dans le JSON). Un thème changé
  par `.idalgoTheme(_:)` redessine les composants sans les relire.
- **Trois niveaux** : le widget (une ligne) ; les briques, sans état, sur des données déjà lues,
  thémées seules ou dans un composant ; les états (`IdalgoScoreCenterModel`,
  `IdalgoMatchSheetModel`) : `run()` lit et suit le direct tant que la tâche vit, un seul suivi
  pour plusieurs lecteurs, en pause en arrière-plan ; entrées modifiables sur place. Les widgets
  reposent sur ces états et ces briques (`init(model:)` pour partager l'état de l'app).
- **Composants remplaçables** : `IdalgoComponents` (protocole, chaque partie a sa version du SDK) ;
  ceux du SDK sont rendus sans `AnyView`, ceux de l'app sont effacés une fois par partie.
- **Routeur** : raccourci du composant (`onContestTap`, `onTeamTap`, `onTap`), puis
  `.idalgoNavigation`, puis l'écran du SDK (feuille de match pour un duel, classement en feuille ;
  rien pour une équipe). Une brique sans raccourci ni routeur n'est pas touchable.
- **Compétition** : `IdalgoStandingsView(competition:)` lit `currentSeason` par
  `GET /v1/competitions?ids=` (la route `/v1/competitions/{id}` n'existe pas), gardé par client ;
  `client.competitions(sport:)` suit les pages (100 par page).
- **Score Center** : flèches vers les jours voisins qui ont des matchs, filtre Tous / En cours /
  Terminés / À venir appliqué au jour chargé (avec le nombre de matchs), un bloc par compétition
  (« Classement » ouvre le classement de la saison dans une feuille, sauf en phase à élimination).
  Le fuseau du jour et des heures est celui de l'appareil, toujours envoyé en `timeZone`.
- **Feuille de match** : en-tête (équipes, place au classement, score ou heure, mi-temps, direct,
  buteurs avec « (pen.) » et « (c.s.c.) »), onglets épinglés au défilement. Infos : compétition,
  date, arbitres, stade, capacité, affluence. Actions : domicile à gauche, extérieur à droite, score
  après chaque but, coupures « Mi-temps » et « Fin du match ». Compos : une équipe à la fois, le
  terrain (titulaires à leurs coordonnées, gardien en haut, badges but / carton / sortie /
  capitaine), entraîneur, remplaçants et leur entrée. Avant-match : forme (V / N / D), classement
  à la date du match (général, domicile, extérieur), joueurs clés, confrontations. Rubrique
  ouverte d'emblée : les actions d'un match commencé, l'avant-match sinon (`initialTab` la choisit).
- **Navigation** : sans `onContestTap`, un match touché dans le Score Center ouvre la feuille du
  SDK, poussée s'il y a une pile de navigation, sinon en feuille modale avec « Fermer ». Une sonde
  UIKit trouve la pile : dans une `NavigationStack`, la feuille est poussée par
  `navigationDestination` ; dans la `UINavigationController` d'une app UIKit (sans
  `NavigationStack`), dans un `UIHostingController` poussé sur cette pile.
  `.idalgoContestPresentation(.push | .sheet)` force l'un ou l'autre. La feuille ouverte reçoit le
  thème, le client et le fuseau (`timeZone`) du Score Center.
- **Direct** : `scoreCenterUpdates` et `matchSheetUpdates` donnent le document puis ses mises à
  jour (`AsyncThrowingStream`) ; les widgets les lisent eux aussi. Mêmes règles que les widgets
  web : la relecture de `/live` commence 90 min avant le premier coup d'envoi du jour (tout de
  suite si un match est en cours), suit `pollAfter`, s'arrête quand il vaut `nil` ; après une
  erreur passagère, nouvel essai dans 30 s. Elle s'arrête quand la vue disparaît ou que l'app
  passe en arrière-plan, et reprend aussitôt au retour. Le direct de la feuille de match remplace
  en-tête, actions et compositions ; l'avant-match reste celui de la première lecture.
- **Client** : `Authorization: Bearer` si une clé publique est donnée, `?lang=`, paramètres
  triés, cache mémoire (`max-age`, puis `If-None-Match` / 304). Les routes `/live` vont toujours
  au réseau (avec `If-None-Match`) : leur `max-age=60` ne bride pas un `pollAfter` plus court.
  Deux lectures identiques en cours partagent un seul appel. Deux nouvelles tentatives (300 ms
  puis 900 ms) sur erreur réseau, 5xx ou 429 ; sur 429 ou 503, l'attente est celle de
  `Retry-After` (secondes ou date HTTP), 60 s au plus. Délai de 10 s par défaut
  (`URLSessionTransport(timeout:)` le change). Une seule session réseau, gardée quand
  `Idalgo.configure` est rappelé.
- **Identification** : chaque requête envoie `X-Idalgo-App: <bundle id>` et
  `User-Agent: IdalgoKit-iOS/0.9.0 (<bundle id>; iOS 18.2)`, pour le suivi de la consommation.
  `Idalgo.version` suit `mobile/VERSION` (vérifié en CI par `mobile/scripts/check-version.sh`).
- **Clé secrète** : une clé `idl_sk_…` (réservée aux serveurs) passée à `configure` ou à un
  client n'est jamais envoyée ; une erreur est journalisée, et une build de debug s'arrête sur une
  assertion.
- **Erreurs** : le client ne lève que `IdalgoError` (`.api(status:code:detail:)`,
  `.network(code:message:)` avec le code `URLError` quand il y en a un, `.decoding`), ou
  `CancellationError` quand la tâche est annulée. Les flux du direct ne gardent que le dernier
  document pour un lecteur lent.
- **Images** : logos, drapeaux et portraits passent par un cache mémoire (`NSCache`) sur la
  session du SDK : une image déjà lue s'affiche aussitôt, sans nouvel appel ; un 404 n'est pas
  redemandé.
- **Accessibilité** : le point du direct et le squelette de chargement ne pulsent plus quand
  « Réduire les animations » est activé.

## Commandes

Depuis `mobile/ios` :

```bash
swift test                       # tests (décodage, thème, formatage, client, direct, navigation)
../scripts/check-version.sh ios  # Idalgo.version = mobile/VERSION
```

App de démo, depuis `mobile/ios/Demo` (XcodeGen : `brew install xcodegen`, seulement pour
régénérer le projet après un ajout de fichier) :

```bash
xcodegen generate                # régénère IdalgoDemo.xcodeproj depuis project.yml

SIM=<UDID du simulateur>         # xcrun simctl list devices booted
xcodebuild -project IdalgoDemo.xcodeproj -scheme IdalgoDemo \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build/DerivedData build
xcrun simctl install $SIM build/DerivedData/Build/Products/Debug-iphonesimulator/IdalgoDemo.app
xcrun simctl launch $SIM live.idalgo.demo                       # liste des compétitions
xcrun simctl launch $SIM live.idalgo.demo -season 369003        # ouvre un classement
xcrun simctl launch $SIM live.idalgo.demo -season 374703 -appearance dark
xcrun simctl launch $SIM live.idalgo.demo -scoreCenter 2026-11-08  # Score Center à ce jour (ou today)
xcrun simctl launch $SIM live.idalgo.demo -liveDemo                # direct simulé
xcrun simctl launch $SIM live.idalgo.demo -contest 54732603 -tab lineups  # feuille de match (info|actions|lineups|preview)
xcrun simctl launch $SIM live.idalgo.demo -liveMatch               # feuille en direct simulé
xcrun simctl launch $SIM live.idalgo.demo -uikitHost               # Score Center dans une UINavigationController
xcrun simctl launch $SIM live.idalgo.demo -blocks                  # écran « Briques » (état, briques, routeur)
xcrun simctl launch $SIM live.idalgo.demo -uikitControllers        # IdalgoMatchSheetViewController
xcrun simctl launch $SIM live.idalgo.demo -liveDemo -theme tokens  # jetons : compact, transparent, natif
xcrun simctl io $SIM screenshot capture.png

# Tests d'interface (captures gardées dans le résultat) : « Classement » depuis un bloc, match
# touché → feuille de match poussée (NavigationStack, et UINavigationController d'une app UIKit),
# terrain des compositions.
xcodebuild test -project IdalgoDemo.xcodeproj -scheme IdalgoDemo \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build/DerivedData \
  -resultBundlePath build/ui.xcresult
xcrun xcresulttool export attachments --path build/ui.xcresult --output-path build/captures
```

La démo lit l'API de production (`https://api.idalgo.live`, sans clé) : Score Center du football,
Ligue 1 (374703), NBA (46602), Ligue des Nations (369003, 14 poules). Le direct simulé
(`-liveDemo`, ou « Direct simulé » dans la liste) sert le module et sa route live depuis
`score-center-scheduled.json` et `score-center-live-inplay.json`, embarqués dans l'app de démo
seulement (`FixtureTransport`, jamais dans le SDK) : coups d'envoi recalés dans l'heure qui vient,
deux matchs en cours (« 45e », « Mi-temps »), un terminé. Le direct simulé de la feuille de match
(`-liveMatch`) sert l'avant-match d'Arsenal – Leeds (`match-sheet-finished.json`) avec l'en-tête, les
actions et les compositions du direct à la 67e (`match-sheet-live-inplay.json`) ; Danemark –
Norvège sert sa feuille à venir. « Hôte UIKit » (ou `-uikitHost`) montre ce direct simulé dans
une `UINavigationController` dont la racine est un `UIHostingController`, comme une app UIKit. Toute autre saison passée en `-season` s'ouvre aussi
(`-season 999999999` montre l'état d'erreur). Le bouton palette change le thème du composant
(iDalgo, Neutre, exemple de média décodé du JSON, « Média compact » : jetons d'apparence et
couleur native). « Briques » (`-blocks`) : carrousel de `IdalgoContestCard`, top 5 de la Ligue 1
autour de Lens (`competition: "103"`, `limit`, `around`), liste de l'app qui mêle ses rubriques et
`IdalgoContests`, une ligne maison (`IdalgoComponents`), et le routeur (équipe prise par l'app,
match laissé au SDK). `-appearance dark|light` force l'apparence :
`xcrun simctl ui <UDID> appearance dark` ne s'applique pas toujours sur le simulateur iOS 26.4.
