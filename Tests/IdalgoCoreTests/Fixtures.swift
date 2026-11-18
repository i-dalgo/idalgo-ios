import Foundation
@testable import IdalgoCore

/// Réponses réelles de l'API, partagées avec le SDK Android (`mobile/fixtures/`). Le dépôt public
/// du paquet (miroir de `mobile/ios`) les copie dans `Tests/Fixtures` ; dans le monorepo, elles
/// sont lues dans `mobile/fixtures`.
enum Fixtures {
    static let directory = resolveDirectory(tests: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // IdalgoCoreTests
        .deletingLastPathComponent()) // Tests

    /// `Tests/Fixtures` s'il existe, sinon `../fixtures` à côté du paquet.
    static func resolveDirectory(tests: URL) -> URL {
        let mirrored = tests.appendingPathComponent("Fixtures")
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: mirrored.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return mirrored
        }
        return tests
            .deletingLastPathComponent() // ios
            .deletingLastPathComponent() // mobile
            .appendingPathComponent("fixtures")
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent("\(name).json"))
    }

    /// `data` d'une réponse du module Score Center enregistrée.
    static func scoreCenter(_ name: String) throws -> ScoreCenter {
        try JSONDecoder().decode(Envelope<ScoreCenter>.self, from: data(name)).data
    }

    /// Réponse enregistrée de la route live du Score Center.
    static func scoreCenterLive(_ name: String) throws -> LiveEnvelope<ScoreCenterLive> {
        try JSONDecoder().decode(LiveEnvelope<ScoreCenterLive>.self, from: data(name))
    }

    /// `data` d'une feuille de match enregistrée.
    static func matchSheet(_ name: String) throws -> MatchSheet {
        try JSONDecoder().decode(Envelope<MatchSheet>.self, from: data(name)).data
    }

    /// Réponse enregistrée de la route live de la feuille de match.
    static func matchSheetLive(_ name: String) throws -> LiveEnvelope<MatchSheetLive> {
        try JSONDecoder().decode(LiveEnvelope<MatchSheetLive>.self, from: data(name))
    }

    /// `data` d'une réponse `/v1/standings` enregistrée.
    static func standings(_ name: String) throws -> Standings {
        try JSONDecoder().decode(Envelope<Standings>.self, from: data(name)).data
    }
}
