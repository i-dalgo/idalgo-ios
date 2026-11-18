import SwiftUI

extension IdalgoError {
    /// Explication montrée au lecteur sous le titre de l'erreur : le détail en français de l'API,
    /// sinon `fallback`, le message de l'écran.
    func readerMessage(fallback: String) -> String {
        switch self {
        case let .api(_, _, detail): detail ?? fallback
        case .network: IdalgoStrings.networkError
        case .decoding: IdalgoStrings.decodingError
        }
    }
}

/// Message d'erreur, et bouton « Réessayer » si `retry` est donné (erreur passagère).
struct ErrorStateView: View {
    let title: String
    let message: String?
    let retry: (() -> Void)?

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(theme.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(theme.headingFont.font(.headline, weight: .semibold))
            if let message {
                Text(message)
                    .font(theme.bodyFont.font(.subheadline))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let retry {
                Button(action: retry) {
                    Text(IdalgoStrings.retry)
                        .font(theme.bodyFont.font(.subheadline, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundStyle(theme.onPrimary)
                        .background(RoundedRectangle(cornerRadius: theme.radius.s).fill(theme.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

/// Message seul, centré (classement vide ou non pris en charge).
struct MessageStateView: View {
    let message: String

    @Environment(\.resolvedIdalgoTheme) private var theme

    var body: some View {
        Text(message)
            .font(theme.bodyFont.font(.subheadline))
            .foregroundStyle(theme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
    }
}

/// Squelette d'un tableau pendant le premier chargement.
struct SkeletonTableView: View {
    var rows = 10

    @Environment(\.resolvedIdalgoTheme) private var theme
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: 10) {
                    bar(width: 16)
                    Circle().fill(theme.surface).frame(width: 22, height: 22)
                    bar(width: CGFloat(80 + (index * 37) % 60))
                    Spacer()
                    ForEach(0..<4, id: \.self) { _ in bar(width: 18) }
                }
                .padding(.horizontal, 16)
                .frame(height: rowHeight)
                .overlay(alignment: .bottom) { theme.border.frame(height: 1 / 3) }
            }
        }
        .pulsing(dimmedOpacity: 0.5, duration: 0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(IdalgoStrings.loading)
    }

    private func bar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: theme.radius.xs).fill(theme.surface).frame(width: width, height: 12)
    }
}

/// Pulsation d'un indicateur (point du direct, squelette) : l'opacité va et vient, sauf si le
/// lecteur a demandé de réduire les animations (l'indicateur reste alors fixe, pleinement visible).
struct Pulsing: ViewModifier {
    let dimmedOpacity: Double
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? dimmedOpacity : 1)
            .animation(Self.animation(duration: duration, reduceMotion: reduceMotion), value: dimmed)
            .onAppear { dimmed = !reduceMotion }
            .onChange(of: reduceMotion) { reduce in dimmed = !reduce }
    }

    /// L'animation de la pulsation ; aucune quand les animations sont réduites.
    nonisolated static func animation(duration: Double, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: duration).repeatForever()
    }
}

extension View {
    func pulsing(dimmedOpacity: Double, duration: Double) -> some View {
        modifier(Pulsing(dimmedOpacity: dimmedOpacity, duration: duration))
    }
}
