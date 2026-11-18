import Foundation

/// Calculs de couleur du thème, portés de `apps/ui-kit/src/utils/color.ts` pour donner les mêmes
/// valeurs que les widgets web : lecture (`#rgb`, `#rrggbb`, `rgb()`), mélange, clarté HSL et
/// contraste WCAG. Une couleur illisible (`red`, `hsl()`…) ne se mélange pas et son contraste
/// n'est pas vérifiable.
package enum ThemeColorMath {
    /// Couleur opaque, canaux de 0 à 255.
    package struct RGB: Equatable, Sendable {
        package let r: Int
        package let g: Int
        package let b: Int

        package init(r: Int, g: Int, b: Int) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    private static let channelMax = 255.0

    /// La couleur en canaux, ou `nil` si elle n'est ni hexadécimale ni `rgb()` opaque.
    package static func parse(_ value: String) -> RGB? {
        let color = value.trimmingCharacters(in: .whitespaces).lowercased()
        if color.hasPrefix("#") { return parseHex(String(color.dropFirst())) }
        guard color.hasPrefix("rgb("), color.hasSuffix(")") else { return nil }
        let channels = color.dropFirst(4).dropLast()
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { Int($0) }
        guard channels.count == 3, channels.allSatisfy({ $0 != nil && $0! <= 255 }) else { return nil }
        return RGB(r: channels[0]!, g: channels[1]!, b: channels[2]!)
    }

    private static func parseHex(_ hex: String) -> RGB? {
        guard hex.count == 3 || hex.count == 6, hex.allSatisfy(\.isHexDigit) else { return nil }
        let full = hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
        let value = Int(full, radix: 16)!
        return RGB(r: value >> 16 & 0xff, g: value >> 8 & 0xff, b: value & 0xff)
    }

    static func hex(_ rgb: RGB) -> String {
        String(format: "#%02x%02x%02x", rgb.r, rgb.g, rgb.b)
    }

    /// `weight` de `color` sur `base` (0 : `base`, 1 : `color`), en hexadécimal ; en `color-mix()`
    /// (comme le web) si l'une des deux ne se lit pas.
    package static func mix(_ color: String, _ base: String, weight: Double) -> String {
        guard let top = parse(color), let bottom = parse(base) else {
            let percent = (weight * 1000).rounded() / 10
            let label = percent == percent.rounded() ? String(Int(percent)) : String(percent)
            return "color-mix(in srgb, \(color) \(label)%, \(base))"
        }
        func blend(_ a: Int, _ b: Int) -> Int { Int((Double(b) + Double(a - b) * weight).rounded()) }
        return hex(RGB(r: blend(top.r, bottom.r), g: blend(top.g, bottom.g), b: blend(top.b, bottom.b)))
    }

    private struct HSL {
        var h: Double
        var s: Double
        var l: Double
    }

    private static func hsl(_ rgb: RGB) -> HSL {
        let (red, green, blue) = (Double(rgb.r) / channelMax, Double(rgb.g) / channelMax, Double(rgb.b) / channelMax)
        let maximum = max(red, green, blue)
        let minimum = min(red, green, blue)
        let l = (maximum + minimum) / 2
        let delta = maximum - minimum
        if delta == 0 { return HSL(h: 0, s: 0, l: l) }
        let s = delta / (1 - abs(2 * l - 1))
        let sector: Double = if maximum == red {
            ((green - blue) / delta + 6).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            (blue - red) / delta + 2
        } else {
            (red - green) / delta + 4
        }
        return HSL(h: sector * 60, s: s, l: l)
    }

    private static func rgb(_ hsl: HSL) -> RGB {
        let chroma = (1 - abs(2 * hsl.l - 1)) * hsl.s
        let x = chroma * (1 - abs((hsl.h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = hsl.l - chroma / 2
        let sectors: [(Double, Double, Double)] = [
            (chroma, x, 0), (x, chroma, 0), (0, chroma, x), (0, x, chroma), (x, 0, chroma), (chroma, 0, x),
        ]
        let (red, green, blue) = sectors[Int(floor(hsl.h / 60)) % 6]
        func channel(_ value: Double) -> Int { Int(((value + m) * channelMax).rounded()) }
        return RGB(r: channel(red), g: channel(green), b: channel(blue))
    }

    /// Clarté HSL (0 : noir, 1 : blanc), ou `nil` si la couleur ne se lit pas.
    package static func lightness(of color: String) -> Double? {
        parse(color).map { hsl($0).l }
    }

    /// La couleur à cette clarté HSL, même teinte et même saturation, ou `nil` si elle ne se lit pas.
    package static func withLightness(_ color: String, _ lightness: Double) -> String? {
        guard let rgb = parse(color) else { return nil }
        var value = hsl(rgb)
        value.l = min(1, max(0, lightness))
        return hex(self.rgb(value))
    }

    /// Luminance relative WCAG 2 : 0 pour le noir, 1 pour le blanc.
    private static func luminance(_ rgb: RGB) -> Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel) / channelMax
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.r) + 0.7152 * linear(rgb.g) + 0.0722 * linear(rgb.b)
    }

    /// Rapport de contraste WCAG (1 à 21), ou `nil` si l'une des couleurs ne se lit pas.
    package static func contrastRatio(_ foreground: String, _ background: String) -> Double? {
        guard let front = parse(foreground), let back = parse(background) else { return nil }
        let (a, b) = (luminance(front), luminance(back))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
