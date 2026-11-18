import Foundation
import os

/// Images du CDN (logos, drapeaux, portraits) gardées en mémoire : une image déjà lue s'affiche
/// aussitôt, sans nouvel appel, quand une ligne revient à l'écran ou qu'un autre composant la
/// montre ; deux demandes simultanées partagent l'appel. Une adresse qui répond une erreur HTTP
/// (404 : pas de logo) n'est plus redemandée ; une erreur réseau, si.
///
/// Les composants passent tous par le même chargeur (`PlatformImage.loader`, côté vues) ; `Image`
/// est l'image décodée de la plateforme.
package final class ImageLoader<Image: Sendable>: Sendable {
    private final class Entry: Sendable {
        let image: Image

        init(_ image: Image) {
            self.image = image
        }
    }

    /// `NSCache` est sûr entre fils ; il se vide de lui-même sous pression mémoire.
    private nonisolated(unsafe) let cache = NSCache<NSURL, Entry>()
    private let failures = OSAllocatedUnfairLock<Set<URL>>(initialState: [])
    let inFlight = InFlightRequests()
    private let transport: any HTTPTransport
    private let decode: @Sendable (Data) -> Image?

    /// - Parameters:
    ///   - transport: par défaut la session partagée du SDK.
    ///   - countLimit: images gardées au plus.
    ///   - decode: décode les octets reçus ; `nil` pour une réponse qui n'est pas une image.
    package init(
        transport: any HTTPTransport = URLSessionTransport.shared,
        countLimit: Int = 300,
        decode: @escaping @Sendable (Data) -> Image?
    ) {
        self.transport = transport
        self.decode = decode
        cache.countLimit = countLimit
    }

    /// L'image si elle est déjà en mémoire.
    package func cached(_ url: URL) -> Image? {
        cache.object(forKey: url as NSURL)?.image
    }

    /// L'image, lue sur le CDN si besoin ; `nil` si l'adresse ne répond pas une image.
    package func image(for url: URL) async -> Image? {
        if let image = cached(url) { return image }
        if failures.withLock({ $0.contains(url) }) { return nil }
        guard let data = try? await inFlight.data(for: url, operation: { try await self.fetch(url) }) else { return nil }
        if let image = cached(url) { return image }
        guard let image = decode(data) else {
            failures.withLock { _ = $0.insert(url) }
            return nil
        }
        cache.setObject(Entry(image), forKey: url as NSURL)
        return image
    }

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await transport.send(URLRequest(url: url))
        guard (200..<300).contains(response.statusCode) else {
            failures.withLock { _ = $0.insert(url) }
            throw URLError(.fileDoesNotExist)
        }
        return data
    }
}
