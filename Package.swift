// swift-tools-version: 6.0
import PackageDescription

// IdalgoKit : SDK iOS d'iDalgo. `IdalgoCore` porte la couche de données, le thème et le formatage
// (Foundation seule, testable sur macOS) ; `IdalgoKit` ajoute les vues SwiftUI et réexporte le cœur.
// Le formatage et la présentation partagés par les deux cibles sont en accès `package` : hors de
// l'API publique.
let package = Package(
    name: "IdalgoKit",
    defaultLocalization: "fr",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "IdalgoKit", targets: ["IdalgoKit"]),
        .library(name: "IdalgoCore", targets: ["IdalgoCore"]),
    ],
    targets: [
        // Manifeste de confidentialité : ni suivi, ni donnée collectée, ni API à justifier.
        .target(name: "IdalgoCore", resources: [.copy("PrivacyInfo.xcprivacy")]),
        .target(name: "IdalgoKit", dependencies: ["IdalgoCore"]),
        .testTarget(name: "IdalgoCoreTests", dependencies: ["IdalgoCore"]),
        .testTarget(name: "IdalgoKitTests", dependencies: ["IdalgoKit"]),
    ],
    swiftLanguageModes: [.v6]
)
