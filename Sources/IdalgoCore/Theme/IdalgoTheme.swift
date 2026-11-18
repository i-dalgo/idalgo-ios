import Foundation

/// Thème des composants : couleurs, couleurs du mode sombre, polices, arrondis et mode. Même forme
/// que le thème d'un média côté web (`ThemeConfig`, `meta.client.theme`), dont il se décode
/// (`IdalgoTheme(json:)`). Les couleurs absentes sont déduites (`palette(for:)`).
public struct IdalgoTheme: Decodable, Sendable, Hashable {
    /// Mode des composants : clair, sombre, ou `auto` qui suit le réglage de l'appareil.
    public enum Mode: String, Decodable, Sendable {
        case light, dark, auto
    }

    /// Couleurs du thème (`#rrggbb`, `#rgb` ou `rgb()`). Les quatre premières sont obligatoires ;
    /// les autres, absentes, sont déduites.
    public struct Colors: Decodable, Sendable, Hashable {
        /// Couleur de marque : fonds pleins (onglet actif), liens.
        public var primary: String
        /// Texte secondaire de marque : libellés, dates.
        public var secondary: String
        /// Fond du composant.
        public var background: String
        /// Texte principal.
        public var text: String
        /// Marque appuyée. Absent : la marque assombrie.
        public var primaryHover: String?
        /// Texte posé sur la marque. Absent : le fond ou le texte, le plus lisible des deux.
        public var onPrimary: String?
        /// Fond léger de marque (ligne mise en avant). Absent : 12 % de la marque sur le fond.
        public var primarySubtle: String?
        /// Fond secondaire : en-têtes de tableau, puces. Absent : le fond, à peine teinté.
        public var surface: String?
        /// Texte secondaire. Absent : le texte éclairci vers le fond.
        public var textSecondary: String?
        /// Bordures et séparateurs. Absent : le texte, très éclairci vers le fond.
        public var border: String?

        public init(
            primary: String, secondary: String, background: String, text: String,
            primaryHover: String? = nil, onPrimary: String? = nil, primarySubtle: String? = nil,
            surface: String? = nil, textSecondary: String? = nil, border: String? = nil
        ) {
            self.primary = primary
            self.secondary = secondary
            self.background = background
            self.text = text
            self.primaryHover = primaryHover
            self.onPrimary = onPrimary
            self.primarySubtle = primarySubtle
            self.surface = surface
            self.textSecondary = textSecondary
            self.border = border
        }
    }

    /// Couleurs du mode sombre, toutes facultatives : chacune remplace sa déduction.
    public struct DarkColors: Decodable, Sendable, Hashable {
        public var primary: String?
        public var secondary: String?
        public var background: String?
        public var text: String?
        public var primaryHover: String?
        public var onPrimary: String?
        public var primarySubtle: String?
        public var surface: String?
        public var textSecondary: String?
        public var border: String?

        public init(
            primary: String? = nil, secondary: String? = nil, background: String? = nil, text: String? = nil,
            primaryHover: String? = nil, onPrimary: String? = nil, primarySubtle: String? = nil,
            surface: String? = nil, textSecondary: String? = nil, border: String? = nil
        ) {
            self.primary = primary
            self.secondary = secondary
            self.background = background
            self.text = text
            self.primaryHover = primaryHover
            self.onPrimary = onPrimary
            self.primarySubtle = primarySubtle
            self.surface = surface
            self.textSecondary = textSecondary
            self.border = border
        }
    }

    /// Polices : noms de familles, ou pile CSS (`Georgia, "Times New Roman", serif`). Une famille
    /// absente de l'app laisse la place à la suivante, puis à la police système.
    public struct Fonts: Decodable, Sendable, Hashable {
        public var heading: String
        public var body: String

        public init(heading: String, body: String) {
            self.heading = heading
            self.body = body
        }
    }

    /// Arrondis des angles, en points, du plus petit au plus grand.
    public struct Radius: Decodable, Sendable, Hashable {
        /// Badges, puces.
        public var xs: Double
        /// Boutons, champs.
        public var s: Double
        /// Panneaux et cartes.
        public var m: Double
        /// Grands blocs.
        public var l: Double

        /// Arrondis du design system : 4, 8, 12 et 16.
        public static let standard = Radius(xs: 4, s: 8, m: 12, l: 16)

        public init(xs: Double, s: Double, m: Double, l: Double) {
            self.xs = xs
            self.s = s
            self.m = m
            self.l = l
        }

        private enum CodingKeys: String, CodingKey { case xs, s, m, l }

        /// Décode les longueurs CSS du thème web (`14px`, `0`, `0.5rem`) ; une valeur absente ou
        /// illisible garde l'arrondi du design system.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            func length(_ key: CodingKeys, _ fallback: Double) throws -> Double {
                try container.decodeIfPresent(String.self, forKey: key).flatMap(Self.points(css:)) ?? fallback
            }
            let standard = Self.standard
            xs = try length(.xs, standard.xs)
            s = try length(.s, standard.s)
            m = try length(.m, standard.m)
            l = try length(.l, standard.l)
        }

        /// Une longueur CSS en points : `px` tel quel, `rem` / `em` sur une base de 16.
        static func points(css: String) -> Double? {
            let value = css.trimmingCharacters(in: .whitespaces).lowercased()
            for (unit, scale) in [("rem", 16.0), ("em", 16.0), ("px", 1.0)] where value.hasSuffix(unit) {
                return Double(value.dropLast(unit.count)).map { $0 * scale }
            }
            return Double(value)
        }
    }

    /// Couleurs d'état : direct, victoire, nul, défaite, cartons (`#rrggbb`, `#rgb` ou `rgb()`),
    /// valables en clair comme en sombre. Absentes : celles du design system, propres à chaque mode.
    public struct StatusColors: Decodable, Sendable, Hashable {
        /// Match en direct : score, minute, point qui pulse. Défaut : rouge « danger ».
        public var live: String?
        /// Victoire (pastille V de la forme récente). Défaut : vert « succès ».
        public var win: String?
        /// Match nul (pastille N). Défaut : le texte secondaire du thème.
        public var draw: String?
        /// Défaite (pastille D de la forme récente). Défaut : rouge « danger ».
        public var loss: String?
        /// Carton jaune. Défaut : `#f5c518`.
        public var yellowCard: String?
        /// Carton rouge. Défaut : `#e5322d`.
        public var redCard: String?

        /// Couleurs d'état ; une couleur absente garde celle du design system.
        public init(
            live: String? = nil, win: String? = nil, draw: String? = nil, loss: String? = nil,
            yellowCard: String? = nil, redCard: String? = nil
        ) {
            self.live = live
            self.win = win
            self.draw = draw
            self.loss = loss
            self.yellowCard = yellowCard
            self.redCard = redCard
        }
    }

    /// Densité des composants : hauteur des lignes et marges.
    public enum Density: String, Decodable, Sendable {
        /// Lignes et marges du design system.
        case regular
        /// Lignes plus basses et marges plus serrées, pour un écran chargé ou une carte.
        case compact
    }

    /// Fond des composants.
    public enum Background: String, Decodable, Sendable {
        /// La couleur `background` du thème.
        case theme
        /// Aucun fond : le composant se fond dans la carte ou l'écran de l'app.
        case transparent
    }

    public var name: String
    public var colors: Colors
    /// Couleurs propres au mode sombre ; absentes, elles sont déduites des couleurs claires.
    public var darkColors: DarkColors
    public var fonts: Fonts
    public var radius: Radius
    public var mode: Mode
    /// Couleurs d'état (direct, victoire, nul, défaite, cartons).
    public var statusColors: StatusColors
    /// Facteur appliqué aux tailles de texte du SDK (de 0,5 à 2 ; 1 par défaut). Les tailles et
    /// graisses du SDK restent la base, et la taille de texte de l'appareil s'applique toujours.
    public var fontScale: Double
    /// Densité : `regular` (défaut) ou `compact`.
    public var density: Density
    /// Fond : celui du thème (défaut) ou transparent.
    public var background: Background
    /// Couleurs natives posées par `IdalgoKit` (`with(_:_:)`), par rôle ; elles priment sur les
    /// couleurs en texte.
    package var nativeColors = NativeColors()

    /// Un thème complet ; `statusColors`, `fontScale`, `density` et `background` gardent les
    /// défauts du design system s'ils ne sont pas donnés.
    public init(
        name: String,
        colors: Colors,
        darkColors: DarkColors = DarkColors(),
        fonts: Fonts = Fonts(heading: "", body: ""),
        radius: Radius = .standard,
        mode: Mode = .light,
        statusColors: StatusColors = StatusColors(),
        fontScale: Double = 1,
        density: Density = .regular,
        background: Background = .theme
    ) {
        self.name = name
        self.colors = colors
        self.darkColors = darkColors
        self.fonts = fonts
        self.radius = radius
        self.mode = mode
        self.statusColors = statusColors
        self.fontScale = fontScale
        self.density = density
        self.background = background
    }

    private enum CodingKeys: String, CodingKey {
        case name, colors, darkColors, fonts, radius, mode, statusColors, fontScale, density, background
    }

    /// Décode un `ThemeConfig` : `mode` absent vaut clair, comme pour les widgets web. Les champs
    /// propres aux SDK (`statusColors`, `fontScale`, `density`, `background`) sont facultatifs ;
    /// une valeur illisible garde le défaut, sans faire échouer le thème.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        colors = try container.decode(Colors.self, forKey: .colors)
        darkColors = try container.decodeIfPresent(DarkColors.self, forKey: .darkColors) ?? DarkColors()
        fonts = try container.decode(Fonts.self, forKey: .fonts)
        radius = try container.decodeIfPresent(Radius.self, forKey: .radius) ?? .standard
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .light
        statusColors = (try? container.decodeIfPresent(StatusColors.self, forKey: .statusColors)) ?? StatusColors()
        fontScale = (try? container.decodeIfPresent(Double.self, forKey: .fontScale)) ?? 1
        density = (try? container.decodeIfPresent(Density.self, forKey: .density)) ?? .regular
        background = (try? container.decodeIfPresent(Background.self, forKey: .background)) ?? .theme
    }

    /// Thème décodé du JSON d'un `ThemeConfig` (celui de la fiche d'un média).
    public init(json: Data) throws {
        self = try JSONDecoder().decode(IdalgoTheme.self, from: json)
    }

    /// Le même thème dans un autre mode.
    public func with(mode: Mode) -> IdalgoTheme {
        var theme = self
        theme.mode = mode
        return theme
    }

    /// Facteur de taille de texte effectif : `fontScale` borné à 0,5…2 (1 s'il n'est pas un nombre).
    package var effectiveFontScale: Double {
        fontScale.isFinite ? min(max(fontScale, 0.5), 2) : 1
    }
}

/// Rôle d'une couleur d'état du thème (`IdalgoTheme.StatusColors`).
public enum ThemeStatusRole: String, Sendable, CaseIterable {
    case live, win, draw, loss, yellowCard, redCard
}

extension IdalgoTheme.StatusColors {
    /// Couleur d'un rôle d'état, si le thème la donne.
    public subscript(role: ThemeStatusRole) -> String? {
        switch role {
        case .live: live
        case .win: win
        case .draw: draw
        case .loss: loss
        case .yellowCard: yellowCard
        case .redCard: redCard
        }
    }
}

/// Couleurs natives d'un thème (SwiftUI `Color`, posées par `IdalgoKit`), par nom de rôle. Le cœur
/// ne les lit pas : il les garde pour les vues. Une couleur SwiftUI est `Sendable` et `Hashable`.
package struct NativeColors: Hashable, @unchecked Sendable {
    package var values: [String: AnyHashable] = [:]

    package init() {}

    package subscript(key: String) -> AnyHashable? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

extension IdalgoTheme {
    /// Police du design system ; la police système la remplace si l'app ne l'embarque pas.
    static let designSystemFont = "Atkinson Hyperlegible"

    /// Thème par défaut, aux couleurs d'idalgo.fr (bleu nuit), qui suit le mode de l'appareil.
    public static let `default` = IdalgoTheme(
        name: "iDalgo",
        colors: Colors(
            primary: "#2e3059", secondary: "#45476b", background: "#ffffff", text: "#1e1e1e",
            primaryHover: "#10154d", onPrimary: "#ffffff", primarySubtle: "#e3e4ec",
            surface: "#f1f2f6", textSecondary: "#5f6180", border: "#d9dbe6"
        ),
        fonts: Fonts(heading: designSystemFont, body: designSystemFont),
        mode: .auto
    )

    /// Thème neutre : les gris du design system (thème `dev` des widgets web).
    public static let neutral = IdalgoTheme(
        name: "Neutre",
        colors: Colors(
            primary: "#2c2c2c", secondary: "#444444", background: "#ffffff", text: "#1e1e1e",
            primaryHover: "#1e1e1e", onPrimary: "#f5f5f5", primarySubtle: "#e6e6e6",
            surface: "#f5f5f5", textSecondary: "#757575", border: "#d9d9d9"
        ),
        fonts: Fonts(heading: designSystemFont, body: designSystemFont),
        mode: .auto
    )
}
