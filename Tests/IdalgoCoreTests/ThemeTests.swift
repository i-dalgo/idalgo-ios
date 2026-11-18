import Foundation
import Testing
@testable import IdalgoCore

/// Cas repris de `apps/ui-kit/src/utils/theme.test.ts` : mêmes thèmes, mêmes valeurs attendues.
@Suite("Thème")
struct ThemeTests {
    typealias Math = ThemeColorMath

    static let minimal = IdalgoTheme(
        name: "Ancienne fiche",
        colors: .init(primary: "#c00", secondary: "#333", background: "#fff", text: "#111"),
        fonts: .init(heading: "Georgia", body: "Arial")
    )

    /// `mockCustomTheme` de l'ui-kit, en JSON comme dans la fiche d'un média.
    static let customJSON = """
    {
      "name": "Exemple de média",
      "colors": { "primary": "#b3122e", "secondary": "#5c4a4f", "background": "#fffdf9", "text": "#1f1416" },
      "fonts": { "heading": "Georgia, \\"Times New Roman\\", serif", "body": "Georgia, \\"Times New Roman\\", serif" },
      "radius": { "xs": "8px", "s": "14px", "m": "20px", "l": "1.75rem" }
    }
    """

    static func custom() throws -> IdalgoTheme {
        try IdalgoTheme(json: Data(customJSON.utf8))
    }

    // MARK: Couleurs

    @Test("lit l'hexadécimal court et long et rgb(), refuse le reste")
    func parse() {
        #expect(Math.parse("#c00") == .init(r: 204, g: 0, b: 0))
        #expect(Math.parse(" #2C2C2C ") == .init(r: 44, g: 44, b: 44))
        #expect(Math.parse("rgb(10, 20, 30)") == .init(r: 10, g: 20, b: 30))
        #expect(Math.parse("rgb(10 20 300)") == nil)
        #expect(Math.parse("red") == nil)
        #expect(Math.parse("#12345") == nil)
    }

    @Test("mélange en hexadécimal, ou en color-mix() pour une couleur illisible")
    func mix() {
        #expect(Math.mix("#000000", "#ffffff", weight: 0.5) == "#808080")
        #expect(Math.mix("red", "#ffffff", weight: 0.12) == "color-mix(in srgb, red 12%, #ffffff)")
    }

    @Test("clarté HSL : même teinte, plus claire ; nil si illisible")
    func lightness() throws {
        #expect(abs(try #require(Math.lightness(of: "#ff0000")) - 0.5) < 0.01)
        #expect(Math.withLightness("#ff0000", 0.75) == "#ff8080")
        #expect(Math.withLightness("#808080", 1.4) == "#ffffff")
        #expect(Math.withLightness("#2e3059", try #require(Math.lightness(of: "#2e3059"))) == "#2e3059")
        #expect(Math.lightness(of: "red") == nil)
        #expect(Math.withLightness("red", 0.5) == nil)
    }

    @Test("contraste WCAG : 21 du noir au blanc, nil si illisible")
    func contrast() throws {
        #expect(abs(try #require(Math.contrastRatio("#000", "#fff")) - 21) < 0.01)
        #expect(abs(try #require(Math.contrastRatio("#757575", "#ffffff")) - 4.6) < 0.05)
        #expect(Math.contrastRatio("red", "#fff") == nil)
    }

    // MARK: Palette claire

    @Test("une ancienne fiche (quatre couleurs) donne une palette complète")
    func minimalPalette() {
        let palette = Self.minimal.palette(for: .light)
        #expect(palette.onPrimary == "#fff")
        #expect(palette.primarySubtle == "#f9e0e0")
        #expect(palette.primary == "#c00")
    }

    @Test("la marque appuyée par défaut assombrit la marque")
    func primaryHover() {
        #expect(Self.minimal.palette(for: .light).primaryHover == "#ad0000")
    }

    @Test("un thème complet garde ses couleurs")
    func completePalette() {
        let colors = IdalgoTheme.neutral.colors
        let palette = IdalgoTheme.neutral.palette(for: .light)
        #expect(palette.surface == colors.surface)
        #expect(palette.border == colors.border)
        #expect(palette.textSecondary == colors.textSecondary)
    }

    // MARK: JSON

    @Test("se décode d'un ThemeConfig : arrondis CSS en points, mode absent = clair")
    func decodeJSON() throws {
        let theme = try Self.custom()
        #expect(theme.colors.primary == "#b3122e")
        #expect(theme.fonts.body.hasPrefix("Georgia"))
        #expect(theme.radius == .init(xs: 8, s: 14, m: 20, l: 28))
        #expect(theme.mode == .light)
        #expect(theme.darkColors == .init())
    }

    @Test("arrondis absents ou illisibles : ceux du design system")
    func radiusFallback() throws {
        let json = ##"{"name":"x","colors":{"primary":"#000","secondary":"#000","background":"#fff","text":"#000"},"fonts":{"heading":"a","body":"b"},"radius":{"s":"0","m":"auto"},"mode":"auto"}"##
        let theme = try IdalgoTheme(json: Data(json.utf8))
        #expect(theme.radius == .init(xs: 4, s: 0, m: 12, l: 16))
        #expect(theme.mode == .auto)
    }

    @Test("un mode inconnu est refusé")
    func invalidMode() {
        let json = ##"{"name":"x","colors":{"primary":"#000","secondary":"#000","background":"#fff","text":"#000"},"fonts":{"heading":"a","body":"b"},"mode":"night"}"##
        #expect(throws: DecodingError.self) { try IdalgoTheme(json: Data(json.utf8)) }
    }

    @Test("le thème par défaut suit l'appareil")
    func defaultMode() {
        #expect(IdalgoTheme.default.mode == .auto)
        #expect(IdalgoTheme.default.paletteMode(system: .dark) == .dark)
        #expect(IdalgoTheme.default.with(mode: .light).paletteMode(system: .dark) == .light)
    }

    // MARK: Contraste du thème

    @Test("les thèmes neutre, iDalgo et d'exemple sont lisibles (AA), en clair comme en sombre")
    func readableThemes() throws {
        #expect(IdalgoTheme.neutral.contrastIssues().isEmpty)
        #expect(IdalgoTheme.default.contrastIssues().isEmpty)
        #expect(try Self.custom().contrastIssues().isEmpty)
    }

    @Test("signale un texte trop pâle et une couleur non vérifiable")
    func contrastIssues() {
        var theme = Self.minimal
        theme.colors.text = "#bbbbbb"
        theme.colors.secondary = "slategray"
        let issues = theme.contrastIssues()
        #expect(issues.contains { $0.mode == .light && $0.foreground == .text && $0.background == .background && $0.minimum == 4.5 })
        #expect(issues.contains(.init(mode: .light, foreground: .secondary, background: .background, ratio: nil, minimum: 4.5)))
    }

    @Test("signale une couleur sombre du média peu lisible")
    func darkContrastIssue() {
        var theme = Self.minimal
        theme.darkColors.primary = "#330000"
        let issues = theme.contrastIssues()
        #expect(issues.contains { $0.mode == .dark && $0.foreground == .primary && $0.background == .background })
        #expect(issues.allSatisfy { $0.mode == .dark })
    }

    // MARK: Mode sombre

    @Test("fond et texte s'inversent, la marque garde sa teinte et se lit (≥ 7:1)")
    func darkInversion() throws {
        let theme = IdalgoTheme.default
        let palette = theme.palette(for: .dark)
        #expect(palette.background == theme.colors.text)
        #expect(palette.text == theme.colors.background)
        #expect(try #require(Math.contrastRatio(palette.primary, palette.background)) >= 7)
        let light = try #require(Math.parse(theme.colors.primary))
        let dark = try #require(Math.parse(palette.primary))
        #expect(dark.b > dark.r)
        #expect(light.b > light.r)
        #expect(palette.onPrimary == palette.background)
    }

    @Test("un texte clair trop pâle pour faire un fond sombre est assombri")
    func darkenedBackground() throws {
        var theme = Self.minimal
        theme.colors.text = "#555555"
        let palette = theme.palette(for: .dark)
        #expect(try #require(Math.contrastRatio(palette.text, palette.background)) >= 12)
    }

    @Test("les couleurs sombres du thème remplacent les déductions")
    func darkOverrides() {
        var theme = Self.minimal
        theme.darkColors = .init(primary: "#ff8080", background: "#101020", border: "#333344")
        let palette = theme.palette(for: .dark)
        #expect(palette.background == "#101020")
        #expect(palette.primary == "#ff8080")
        #expect(palette.border == "#333344")
        #expect(palette.text == "#fff")
    }

    @Test("un thème déjà sombre reste tel quel")
    func alreadyDark() {
        var night = Self.minimal
        night.colors = .init(primary: "#ffcc00", secondary: "#cccccc", background: "#111111", text: "#eeeeee")
        #expect(night.palette(for: .dark) == night.palette(for: .light))
    }

    @Test("sombre : fond #1e1e1e et texte blanc pour le thème neutre")
    func neutralDark() {
        let palette = IdalgoTheme.neutral.palette(for: .dark)
        #expect(palette.background == "#1e1e1e")
        #expect(palette.text == "#ffffff")
    }

    @Test("sombre du thème d'exemple : fond = son texte, marque éclaircie")
    func customDark() throws {
        let theme = try Self.custom()
        let palette = theme.palette(for: .dark)
        #expect(palette.background == "#1f1416")
        #expect(palette.text == "#fffdf9")
        #expect(palette.primary != "#b3122e")
        #expect(palette.primary.range(of: "^#[0-9a-f]{6}$", options: .regularExpression) != nil)
    }
}
