import os
import SwiftUI

/// Un thème dans un mode, en couleurs et polices SwiftUI. Une couleur que le SDK ne sait pas
/// lire (`red`, `hsl()`…) prend la valeur du thème par défaut pour le même rôle ; une couleur
/// native (`IdalgoTheme.with(_:_:)`) prime sur la couleur en texte.
struct ResolvedTheme: Sendable {
    let primary: Color
    let onPrimary: Color
    let primarySubtle: Color
    let secondary: Color
    /// Fond du thème, toujours opaque (en-têtes épinglés, pastilles posées sur le terrain).
    let background: Color
    /// Fond posé sous les composants : celui du thème, ou transparent (`IdalgoTheme.background`).
    let containerBackground: Color
    let surface: Color
    let text: Color
    let textSecondary: Color
    let border: Color
    /// Valeur en hausse (différence positive, place gagnée), victoire.
    let positive: Color
    /// Valeur en baisse, défaite.
    let negative: Color
    /// Match en direct (couleur « danger » du design system, comme le badge web).
    let live: Color
    /// Pastilles de forme.
    let win: Color
    let draw: Color
    let loss: Color
    /// Cartons.
    let yellowCard: Color
    let redCard: Color
    let radius: IdalgoTheme.Radius
    let headingFont: ThemeFont
    let bodyFont: ThemeFont
    /// Densité compacte : lignes plus basses, marges plus serrées.
    let isCompact: Bool

    /// Cartons du design system, lisibles en clair comme en sombre.
    static let defaultYellowCard = "#f5c518"
    static let defaultRedCard = "#e5322d"

    init(_ theme: IdalgoTheme, mode: PaletteMode, dynamicTypeSize: DynamicTypeSize = .large) {
        let palette = theme.palette(for: mode)
        let fallback = IdalgoTheme.default.palette(for: mode)
        let native = theme.nativeColors
        func color(_ role: ThemeRole) -> Color {
            native[role.nativeKey] as? Color
                ?? Color(themeColor: palette[role]) ?? Color(themeColor: fallback[role]) ?? .primary
        }
        primary = color(.primary)
        onPrimary = color(.onPrimary)
        primarySubtle = color(.primarySubtle)
        secondary = color(.secondary)
        background = color(.background)
        containerBackground = theme.background == .transparent ? .clear : background
        surface = color(.surface)
        text = color(.text)
        textSecondary = color(.textSecondary)
        border = color(.border)
        // Couleurs d'état du design system (`--color-text-success-secondary`, `…-danger-secondary`).
        let success = Color(themeColor: mode == .dark ? "#85e0a3" : "#009951")!
        let danger = Color(themeColor: mode == .dark ? "#f4776a" : "#c00f0c")!
        func status(_ role: ThemeStatusRole, _ standard: Color) -> Color {
            native[role.nativeKey] as? Color ?? theme.statusColors[role].flatMap(Color.init(themeColor:)) ?? standard
        }
        positive = success
        negative = danger
        live = status(.live, danger)
        win = status(.win, success)
        draw = status(.draw, textSecondary)
        loss = status(.loss, danger)
        yellowCard = status(.yellowCard, Color(themeColor: Self.defaultYellowCard)!)
        redCard = status(.redCard, Color(themeColor: Self.defaultRedCard)!)
        radius = theme.radius
        let scale = theme.effectiveFontScale
        headingFont = ThemeFont(stack: theme.fonts.heading, scale: scale, dynamicTypeSize: dynamicTypeSize)
        bodyFont = ThemeFont(stack: theme.fonts.body, scale: scale, dynamicTypeSize: dynamicTypeSize)
        isCompact = theme.density == .compact
    }

    /// Une hauteur ou une marge selon la densité : telle quelle, ou réduite d'un quart en compact.
    func dense(_ value: CGFloat) -> CGFloat {
        isCompact ? (value * 0.75).rounded() : value
    }
}

extension ResolvedTheme {
    private struct Key: Hashable {
        let theme: IdalgoTheme
        let mode: PaletteMode
        /// Taille de texte de l'appareil, utile seulement quand `fontScale` change les tailles.
        let dynamicTypeSize: DynamicTypeSize?
    }

    /// Thèmes déjà résolus : la déduction des couleurs et la recherche des polices installées ne
    /// se refont pas à chaque rendu.
    private static let resolved = OSAllocatedUnfairLock<[Key: ResolvedTheme]>(initialState: [:])
    /// Au-delà, le cache repart de zéro (une app n'a que quelques thèmes).
    static let cacheLimit = 32

    /// Le thème résolu dans ce mode, calculé une fois.
    static func cached(_ theme: IdalgoTheme, mode: PaletteMode, dynamicTypeSize: DynamicTypeSize = .large) -> ResolvedTheme {
        let size = theme.effectiveFontScale == 1 ? nil : dynamicTypeSize
        let key = Key(theme: theme, mode: mode, dynamicTypeSize: size)
        if let hit = resolved.withLock({ $0[key] }) { return hit }
        let resolvedTheme = ResolvedTheme(theme, mode: mode, dynamicTypeSize: dynamicTypeSize)
        resolved.withLock { cache in
            if cache.count >= cacheLimit { cache.removeAll() }
            cache[key] = resolvedTheme
        }
        return resolvedTheme
    }

    /// Thèmes gardés (tests).
    static var cachedCount: Int { resolved.withLock { $0.count } }
}

extension Color {
    /// Couleur d'un thème (`#rgb`, `#rrggbb`, `rgb()`), ou `nil` si elle ne se lit pas.
    init?(themeColor: String) {
        guard let rgb = ThemeColorMath.parse(themeColor) else { return nil }
        self.init(.sRGB, red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }
}

extension ThemeRole {
    var nativeKey: String { rawValue }
}

extension ThemeStatusRole {
    var nativeKey: String { "status.\(rawValue)" }
}

extension IdalgoTheme {
    /// Le même thème, la couleur d'un rôle remplacée par une couleur SwiftUI : couleur dynamique
    /// (clair / sombre), couleur du catalogue d'assets de l'app… Elle s'affiche telle quelle dans
    /// les deux modes (une couleur dynamique suit le mode du composant) ; les couleurs déduites des
    /// autres rôles restent calculées depuis les couleurs en texte.
    ///
    /// ```swift
    /// let theme = IdalgoTheme.default
    ///     .with(.primary, Color("BrandBlue"))
    ///     .with(.live, .orange)
    /// ```
    public func with(_ role: ThemeRole, _ color: Color) -> IdalgoTheme {
        var theme = self
        theme.nativeColors[role.nativeKey] = AnyHashable(color)
        return theme
    }

    /// Le même thème, une couleur d'état (direct, victoire, nul, défaite, cartons) remplacée par
    /// une couleur SwiftUI ; elle prime sur `statusColors`.
    public func with(_ role: ThemeStatusRole, _ color: Color) -> IdalgoTheme {
        var theme = self
        theme.nativeColors[role.nativeKey] = AnyHashable(color)
        return theme
    }

    #if canImport(UIKit)
    /// Le même thème, la couleur d'un rôle remplacée par une `UIColor` (dynamique comprise).
    public func with(_ role: ThemeRole, uiColor: UIColor) -> IdalgoTheme {
        with(role, Color(uiColor: uiColor))
    }

    /// Le même thème, une couleur d'état remplacée par une `UIColor` (dynamique comprise).
    public func with(_ role: ThemeStatusRole, uiColor: UIColor) -> IdalgoTheme {
        with(role, Color(uiColor: uiColor))
    }
    #endif
}
