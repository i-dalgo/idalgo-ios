import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Police d'un thème : la première famille de la pile installée dans l'app, sinon la police
/// système (avec empattements si la pile finit par `serif`). Suit la taille de texte de l'appareil,
/// multipliée par le `fontScale` du thème.
struct ThemeFont: Sendable {
    let family: String?
    let design: Font.Design
    /// `fontScale` du thème, borné.
    let scale: CGFloat
    /// Taille de texte de l'appareil, pour la police système agrandie ou réduite.
    let dynamicTypeSize: DynamicTypeSize

    init(stack: String, scale: Double = 1, dynamicTypeSize: DynamicTypeSize = .large) {
        let names = stack.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        family = names.first(where: Self.isInstalled)
        design = names.contains("serif") ? .serif : names.contains("monospace") ? .monospaced : .default
        self.scale = CGFloat(scale)
        self.dynamicTypeSize = dynamicTypeSize
    }

    func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        if let family {
            return .custom(family, size: Self.baseSize(style) * scale, relativeTo: style).weight(weight)
        }
        guard scale != 1 else { return .system(style, design: design).weight(weight) }
        return .system(size: scaledSize(style), weight: weight, design: design)
    }

    /// Taille de la police système agrandie : la taille de référence × `scale`, portée à la taille
    /// de texte de l'appareil comme le ferait le style.
    func scaledSize(_ style: Font.TextStyle) -> CGFloat {
        let base = Self.baseSize(style) * scale
        #if canImport(UIKit)
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: Self.uiStyle(style)).scaledValue(for: base, compatibleWith: traits)
        #else
        return base
        #endif
    }

    private static func isInstalled(_ family: String) -> Bool {
        #if canImport(UIKit)
        UIFont.familyNames.contains(family)
        #elseif canImport(AppKit)
        NSFontManager.shared.availableFontFamilies.contains(family)
        #else
        false
        #endif
    }

    /// Taille de référence (taille de texte par défaut) d'un style.
    static func baseSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }

    #if canImport(UIKit)
    private static func uiStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
    #endif
}

#if canImport(UIKit)
private extension UIContentSizeCategory {
    init(_ size: DynamicTypeSize) {
        self = switch size {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
#endif
