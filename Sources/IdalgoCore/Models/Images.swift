import Foundation

/// Une image du CDN des médias iDalgo, avec ses dimensions en pixels.
public struct IdalgoImage: Decodable, Sendable, Hashable {
    public let url: URL
    public let width: Int
    public let height: Int

    public init(url: URL, width: Int, height: Int) {
        self.url = url
        self.width = width
        self.height = height
    }
}

/// Logo carré d'une équipe ou d'une compétition : `small` en 32 px, `large` en 100 px. Servi pour
/// le football ; l'adresse peut répondre 404 (prévoir un repli).
public struct Logo: Decodable, Sendable, Hashable {
    public let small: IdalgoImage
    public let large: IdalgoImage

    public init(small: IdalgoImage, large: IdalgoImage) {
        self.small = small
        self.large = large
    }
}
