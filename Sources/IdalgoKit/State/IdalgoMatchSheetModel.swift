import Combine
import Foundation

/// État de la feuille de match, pour construire son propre écran autour des briques
/// (`IdalgoMatchHeader`, `IdalgoActionsTimeline`, `IdalgoLineupPitch`, `IdalgoPreMatch`) : la
/// feuille lue, suivie en direct pendant le match, et la rubrique ouverte. Le widget
/// `IdalgoMatchSheetView` repose sur le même état.
///
/// Changer `contest` relance la lecture sans recréer l'état. `run()` lit et suit la feuille tant
/// que la tâche qui l'appelle vit ; la lecture se suspend en arrière-plan et reprend au retour.
///
/// ```swift
/// @StateObject private var model = IdalgoMatchSheetModel(contest: "54732603")
///
/// var body: some View {
///     ScrollView {
///         if let sheet = model.sheet {
///             IdalgoMatchHeader(sheet: sheet)
///             IdalgoActionsTimeline(sheet: sheet)
///         }
///     }
///     .task { await model.run() }
/// }
/// ```
@MainActor
public final class IdalgoMatchSheetModel: ObservableObject {
    /// La feuille : en cours de lecture, lue, ou en échec.
    @Published public private(set) var phase: IdalgoPhase<MatchSheet> = .loading
    /// Rubrique ouverte ; `nil` jusqu'à la première lecture si aucune n'a été choisie (elle devient
    /// alors les actions d'un match commencé, l'avant-match sinon).
    @Published public var tab: MatchSheetTab?
    /// Id du match.
    @Published public var contest: String {
        didSet {
            guard contest != oldValue else { return }
            phase = .loading
            tab = initialTab
            runner.restart()
        }
    }
    /// Client à utiliser ; `nil` : `Idalgo.client`.
    public var client: IdalgoClient? { didSet { if client !== oldValue { runner.restart() } } }

    private let initialTab: MatchSheetTab?
    private lazy var runner = LiveRunner { [weak self] in await self?.follow() }

    /// - Parameters:
    ///   - contest: id du match.
    ///   - initialTab: rubrique ouverte d'emblée ; par défaut, les actions d'un match commencé,
    ///     l'avant-match sinon.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    public init(contest: String, initialTab: MatchSheetTab? = nil, client: IdalgoClient? = nil) {
        self.contest = contest
        self.initialTab = initialTab
        tab = initialTab
        self.client = client
    }

    /// La feuille lue, s'il y en a une.
    public var sheet: MatchSheet? { phase.value }

    /// Relit la feuille (après une erreur).
    public func retry() {
        runner.restart()
    }

    /// Lit la feuille puis la suit en direct, jusqu'à l'annulation de la tâche appelante (en
    /// SwiftUI, `.task { await model.run() }`). Plusieurs vues peuvent l'appeler : une seule
    /// lecture tourne.
    public func run() async {
        await runner.run()
    }

    private func follow() async {
        if case .failed = phase { phase = .loading }
        let client = client ?? Idalgo.client
        var received = false
        do {
            for try await sheet in client.matchSheetUpdates(contest: contest) {
                if tab == nil { tab = MatchSheetTab.automatic(for: sheet.contest.status) }
                phase = .loaded(sheet)
                received = true
            }
        } catch is CancellationError {
            return
        } catch {
            // Après une feuille lue, la dernière reste à l'écran.
            if received || Task.isCancelled { return }
            phase = .failed(error as? IdalgoError ?? .network(code: nil, message: error.localizedDescription))
        }
    }
}
