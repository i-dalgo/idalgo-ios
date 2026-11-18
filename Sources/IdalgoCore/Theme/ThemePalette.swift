/// Les dix rôles de couleur d'un thème, déduits des quatre obligatoires quand il ne les donne pas.
/// Règles portées de `apps/ui-kit/src/utils/theme.ts` : un même thème donne les mêmes couleurs
/// sur le web, iOS et Android.
public struct ThemePalette: Sendable, Hashable {
    public var primary: String
    public var primaryHover: String
    public var onPrimary: String
    public var primarySubtle: String
    public var secondary: String
    public var background: String
    public var surface: String
    public var text: String
    public var textSecondary: String
    public var border: String
}

/// Palette effective : claire ou sombre (`auto` choisit l'une ou l'autre selon l'appareil).
public enum PaletteMode: String, Sendable, CaseIterable {
    case light, dark
}

extension IdalgoTheme {
    /// Les couleurs du thème dans un mode, rôles absents déduits.
    public func palette(for mode: PaletteMode) -> ThemePalette {
        mode == .light ? Self.lightPalette(colors) : darkPalette()
    }

    /// Mode effectif : celui du thème, ou celui de l'appareil en `auto`.
    public func paletteMode(system: PaletteMode) -> PaletteMode {
        switch mode {
        case .light: .light
        case .dark: .dark
        case .auto: system
        }
    }
}

// MARK: - Déductions

private enum Derivation {
    /// Assombrissement de la marque appuyée, à défaut d'un `primaryHover`.
    static let hoverDarken = 0.85
    static let black = "#000000"
    static let white = "#ffffff"
    /// Contraste visé par la marque déduite sur le fond sombre : AA avec une marge.
    static let darkBrandContrast = 7.0
    /// Contraste du texte sur le fond sombre déduit, à peu près celui de `#ffffff` sur `#1e1e1e`.
    static let darkBackgroundContrast = 12.0
    static let lightnessStep = 0.01

    /// Couleur la plus lisible sur `background` parmi `candidates` (la première si aucune ne se lit).
    static func mostReadable(on background: String, _ candidates: [String]) -> String {
        var best = candidates[0]
        var bestRatio = 0.0
        for candidate in candidates {
            let ratio = ThemeColorMath.contrastRatio(candidate, background) ?? 0
            if ratio > bestRatio { (best, bestRatio) = (candidate, ratio) }
        }
        return best
    }

    /// `color`, éclaircie ou assombrie pas à pas jusqu'à `minimum` de contraste avec `against` ;
    /// telle quelle si elle l'atteint déjà ou ne se lit pas.
    static func withContrast(_ color: String, against: String, lighter: Bool, minimum: Double) -> String {
        guard let start = ThemeColorMath.lightness(of: color),
              (ThemeColorMath.contrastRatio(color, against) ?? minimum) < minimum
        else { return color }
        let step = lighter ? lightnessStep : -lightnessStep
        var candidate = color
        var lightness = start + step
        while lightness >= 0, lightness <= 1 {
            candidate = ThemeColorMath.withLightness(color, lightness) ?? color
            if (ThemeColorMath.contrastRatio(candidate, against) ?? 0) >= minimum { break }
            lightness += step
        }
        return candidate
    }

    /// Le fond se lit-il mieux avec un texte blanc qu'avec un texte noir ?
    static func isDark(_ color: String) -> Bool {
        (ThemeColorMath.contrastRatio(white, color) ?? 0) > (ThemeColorMath.contrastRatio(black, color) ?? 0)
    }
}

extension IdalgoTheme {
    static func lightPalette(_ colors: Colors) -> ThemePalette {
        let (primary, background, text) = (colors.primary, colors.background, colors.text)
        let mix = ThemeColorMath.mix
        return ThemePalette(
            primary: primary,
            primaryHover: colors.primaryHover ?? mix(primary, Derivation.black, Derivation.hoverDarken),
            onPrimary: colors.onPrimary ?? Derivation.mostReadable(on: primary, [background, text]),
            primarySubtle: colors.primarySubtle ?? mix(primary, background, 0.12),
            secondary: colors.secondary,
            background: background,
            surface: colors.surface ?? mix(text, background, 0.045),
            text: text,
            textSecondary: colors.textSecondary ?? mix(text, background, 0.65),
            border: colors.border ?? mix(text, background, 0.17)
        )
    }

    /// Mode sombre : fond et texte s'inversent (le texte clair devient le fond, assombri s'il ne
    /// l'est pas assez) ; marque et secondaire gardent leur teinte, éclaircis jusqu'à se lire ; le
    /// reste se mélange comme en clair. Chaque couleur de `darkColors` remplace sa déduction. Un
    /// thème au fond déjà sombre reste tel quel.
    func darkPalette() -> ThemePalette {
        if Derivation.isDark(colors.background) { return Self.lightPalette(colors) }
        let text = darkColors.text ?? colors.background
        let background = darkColors.background
            ?? Derivation.withContrast(colors.text, against: text, lighter: false, minimum: Derivation.darkBackgroundContrast)
        func readable(_ color: String) -> String {
            Derivation.withContrast(color, against: background, lighter: true, minimum: Derivation.darkBrandContrast)
        }
        return Self.lightPalette(Colors(
            primary: darkColors.primary ?? readable(colors.primary),
            secondary: darkColors.secondary ?? readable(colors.secondary),
            background: background,
            text: text,
            primaryHover: darkColors.primaryHover,
            onPrimary: darkColors.onPrimary,
            primarySubtle: darkColors.primarySubtle,
            surface: darkColors.surface,
            textSecondary: darkColors.textSecondary,
            border: darkColors.border
        ))
    }
}

// MARK: - Contraste

/// Rôle de couleur d'une palette.
public enum ThemeRole: String, Sendable, CaseIterable {
    case primary, primaryHover, onPrimary, primarySubtle, secondary, background, surface, text, textSecondary, border
}

extension ThemePalette {
    /// Couleur d'un rôle.
    public subscript(role: ThemeRole) -> String {
        switch role {
        case .primary: primary
        case .primaryHover: primaryHover
        case .onPrimary: onPrimary
        case .primarySubtle: primarySubtle
        case .secondary: secondary
        case .background: background
        case .surface: surface
        case .text: text
        case .textSecondary: textSecondary
        case .border: border
        }
    }
}

/// Un texte trop peu lisible sur son fond ; `ratio` `nil` : couleur non vérifiable.
public struct ThemeContrastIssue: Sendable, Hashable {
    public let mode: PaletteMode
    public let foreground: ThemeRole
    public let background: ThemeRole
    public let ratio: Double?
    public let minimum: Double
}

extension IdalgoTheme {
    /// Contraste minimal WCAG AA d'un texte de taille courante.
    public static let minimumTextContrast = 4.5

    /// Les couples texte / fond qu'affichent les composants.
    private static let readablePairs: [(ThemeRole, ThemeRole)] = [
        (.text, .background),
        (.text, .surface),
        (.textSecondary, .background),
        (.secondary, .background),
        (.primary, .background),
        (.primary, .primarySubtle),
        (.onPrimary, .primary),
    ]

    /// Les couples du thème sous le contraste AA, en clair puis en sombre, ou non vérifiables. Ne
    /// rejette jamais le thème : le signalement sert à le corriger.
    public func contrastIssues() -> [ThemeContrastIssue] {
        PaletteMode.allCases.flatMap { mode in
            let palette = palette(for: mode)
            return Self.readablePairs.compactMap { foreground, background -> ThemeContrastIssue? in
                let ratio = ThemeColorMath.contrastRatio(palette[foreground], palette[background])
                if let ratio, ratio >= Self.minimumTextContrast { return nil }
                return ThemeContrastIssue(
                    mode: mode, foreground: foreground, background: background,
                    ratio: ratio, minimum: Self.minimumTextContrast
                )
            }
        }
    }
}
