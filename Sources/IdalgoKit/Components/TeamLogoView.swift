import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Image décodée de la plateforme. Une image décodée ne change plus : la partager entre fils est sûr.
struct PlatformImage: @unchecked Sendable {
    #if canImport(UIKit)
    let image: UIImage

    init?(data: Data) {
        guard let image = UIImage(data: data) else { return nil }
        self.image = image
    }

    var swiftUIImage: Image { Image(uiImage: image) }
    #elseif canImport(AppKit)
    let image: NSImage

    init?(data: Data) {
        guard let image = NSImage(data: data) else { return nil }
        self.image = image
    }

    var swiftUIImage: Image { Image(nsImage: image) }
    #endif

    /// Images des composants, gardées en mémoire sur la session du SDK.
    static let loader = ImageLoader<PlatformImage>(decode: PlatformImage.init(data:))
}

/// Une image du CDN par le cache mémoire du SDK (`ImageLoader`) : affichée aussitôt si elle a déjà
/// été lue, sinon `placeholder` le temps de la lire, ou pour toujours si elle répond 404.
struct CachedImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loaded: (url: URL, image: PlatformImage)?

    var body: some View {
        let image = loaded?.url == url ? loaded?.image : PlatformImage.loader.cached(url)
        Group {
            if let image {
                content(image.swiftUIImage)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            // Déjà en cache (lue entre-temps par une autre vue, ou par cette tâche relancée) : la
            // vue a pu être dessinée avant, avec le repli ; l'état la redessine.
            if let image = PlatformImage.loader.cached(url) {
                if loaded?.url != url { loaded = (url, image) }
                return
            }
            guard let image = await PlatformImage.loader.image(for: url) else { return }
            loaded = (url, image)
        }
    }
}

/// Un logo du CDN : le petit (32 px) s'il suffit à l'écran, sinon le grand (100 px) pour rester
/// net ; `fallback` tant qu'il charge ou s'il répond 404.
struct LogoImage<Fallback: View>: View {
    let logo: Logo
    let size: CGFloat
    @ViewBuilder let fallback: () -> Fallback

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let url = size * displayScale > CGFloat(logo.small.width) ? logo.large.url : logo.small.url
        CachedImage(url: url) { image in
            image.resizable().interpolation(.high).scaledToFit()
        } placeholder: {
            fallback()
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Logo d'une équipe ; ses initiales dans un rond s'il manque, charge ou répond 404.
struct TeamLogoView: View {
    let logo: Logo?
    let name: String?
    let size: CGFloat

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        if let logo {
            LogoImage(logo: logo, size: size) { initials }
        } else {
            initials.frame(width: size, height: size).accessibilityHidden(true)
        }
    }

    private var initials: some View {
        Circle()
            .fill(theme.surface)
            .overlay(Circle().strokeBorder(theme.border, lineWidth: 1))
            .overlay(
                Text(Self.initials(of: name))
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .minimumScaleFactor(0.5)
            )
    }

    /// Premières lettres des deux premiers mots : « Paris SG » → « PS ».
    static func initials(of name: String?) -> String {
        let words = (name ?? "").split(whereSeparator: { $0 == " " || $0 == "-" })
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }
}
