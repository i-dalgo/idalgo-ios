import SwiftUI

private struct IdalgoThemeKey: EnvironmentKey {
    static let defaultValue: IdalgoTheme? = nil
}

private struct ResolvedThemeKey: EnvironmentKey {
    static let defaultValue = ResolvedTheme(IdalgoTheme.default, mode: .light)
}

private struct ThemedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Thème des composants iDalgo sous cette vue ; `nil` : celui de `Idalgo.configuration`.
    var idalgoTheme: IdalgoTheme? {
        get { self[IdalgoThemeKey.self] }
        set { self[IdalgoThemeKey.self] = newValue }
    }

    /// Thème résolu (mode et couleurs SwiftUI), posé par le composant pour ses sous-vues.
    var resolvedIdalgoTheme: ResolvedTheme {
        get { self[ResolvedThemeKey.self] }
        set { self[ResolvedThemeKey.self] = newValue }
    }

    /// Un composant iDalgo a déjà résolu le thème au-dessus : une brique placée dedans ne le refait pas.
    var isInsideIdalgoComponent: Bool {
        get { self[ThemedKey.self] }
        set { self[ThemedKey.self] = newValue }
    }
}

extension View {
    /// Remplace le thème des composants iDalgo de cette vue et de ses enfants. Un nouveau thème
    /// (changé à l'exécution) redessine aussitôt les composants, sans les recréer ni les relire.
    public func idalgoTheme(_ theme: IdalgoTheme) -> some View {
        environment(\.idalgoTheme, theme)
    }
}

/// Résout le thème d'un composant (le sien, sinon le global) dans le mode de l'appareil, et le
/// pose pour ses sous-vues avec son fond, sa couleur de texte et son schéma de couleurs.
struct ThemedContainer: ViewModifier {
    @Environment(\.idalgoTheme) private var override
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let theme = override ?? Idalgo.configuration.theme
        let mode = theme.paletteMode(system: systemScheme == .dark ? .dark : .light)
        let resolved = ResolvedTheme.cached(theme, mode: mode, dynamicTypeSize: dynamicTypeSize)
        content
            .environment(\.resolvedIdalgoTheme, resolved)
            .environment(\.isInsideIdalgoComponent, true)
            .environment(\.colorScheme, mode == .dark ? .dark : .light)
            .foregroundStyle(resolved.text)
            .tint(resolved.primary)
            .background(resolved.containerBackground)
    }
}

/// Thème d'une brique : résolu comme pour un composant si elle est posée seule, gardé tel quel si
/// elle est déjà dans un composant iDalgo.
struct BlockTheming: ViewModifier {
    @Environment(\.isInsideIdalgoComponent) private var inside

    func body(content: Content) -> some View {
        if inside {
            content
        } else {
            content.modifier(ThemedContainer())
        }
    }
}
