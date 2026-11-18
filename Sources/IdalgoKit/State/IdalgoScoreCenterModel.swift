import Combine
import Foundation

/// État du Score Center, pour construire son propre écran autour des briques : le jour lu, suivi en
/// direct pendant les matchs, et le filtre de statut. Le widget `IdalgoScoreCenterView` repose sur
/// le même état.
///
/// Changer une entrée (`date`, `sport`, `competitions`…) relance la lecture, sans recréer l'état.
/// `run()` lit et suit le jour tant que la tâche qui l'appelle vit ; la lecture se suspend quand
/// l'app passe en arrière-plan et reprend au retour.
///
/// ```swift
/// @StateObject private var model = IdalgoScoreCenterModel(sport: "102")
///
/// var body: some View {
///     List {
///         if let day = model.day { IdalgoContests(day: day, status: model.status) }
///     }
///     .task { await model.run() }
/// }
/// ```
@MainActor
public final class IdalgoScoreCenterModel: ObservableObject {
    /// Le jour : en cours de lecture, lu, ou en échec.
    @Published public private(set) var phase: IdalgoPhase<ScoreCenter> = .loading
    /// Une lecture est en cours alors qu'un jour est déjà affiché (autre jour, nouvelle tentative).
    @Published public private(set) var isRefreshing = false
    /// Filtre de statut, appliqué au jour lu (sans nouvelle lecture).
    @Published public var status: IdalgoStatusFilter
    /// Id du sport (`102` : football).
    @Published public var sport: String { didSet { if sport != oldValue { runner.restart() } } }
    /// Compétitions, dans l'ordre des blocs ; vide : la liste par défaut du sport.
    @Published public var competitions: [String] { didSet { if competitions != oldValue { runner.restart() } } }
    /// Jour affiché (`AAAA-MM-JJ`) ; `nil` : aujourd'hui dans le fuseau.
    @Published public var date: String? { didSet { if date != oldValue { runner.restart() } } }
    /// Fuseau IANA du jour et des heures ; `nil` : celui de l'appareil.
    @Published public var timeZone: String? { didSet { if timeZone != oldValue { runner.restart() } } }
    /// Client à utiliser ; `nil` : `Idalgo.client`.
    public var client: IdalgoClient? { didSet { if client !== oldValue { runner.restart() } } }

    private lazy var runner = LiveRunner { [weak self] in await self?.follow() }

    /// - Parameters:
    ///   - sport: id du sport (`102` : football).
    ///   - competitions: compétitions, dans l'ordre des blocs ; vide : la liste par défaut du sport.
    ///   - date: jour affiché d'abord (`AAAA-MM-JJ`) ; par défaut, aujourd'hui.
    ///   - timeZone: fuseau IANA du jour et des heures ; par défaut, celui de l'appareil.
    ///   - status: filtre de statut choisi d'abord.
    ///   - client: client à utiliser ; par défaut `Idalgo.client`.
    public init(
        sport: String,
        competitions: [String] = [],
        date: String? = nil,
        timeZone: String? = nil,
        status: IdalgoStatusFilter = .all,
        client: IdalgoClient? = nil
    ) {
        self.sport = sport
        self.competitions = competitions
        self.date = date
        self.timeZone = timeZone
        self.status = status
        self.client = client
    }

    /// Le jour lu, s'il y en a un.
    public var day: ScoreCenter? { phase.value }

    /// Affiche le jour précédent qui a des matchs (rien s'il n'y en a pas).
    public func showPreviousDay() {
        if let previous = day?.previousDate { date = previous }
    }

    /// Affiche le jour suivant qui a des matchs (rien s'il n'y en a pas).
    public func showNextDay() {
        if let next = day?.nextDate { date = next }
    }

    /// Relit le jour (après une erreur).
    public func retry() {
        runner.restart()
    }

    /// Lit le jour puis le suit en direct, jusqu'à l'annulation de la tâche appelante (en SwiftUI,
    /// `.task { await model.run() }`). Plusieurs vues peuvent l'appeler : une seule lecture tourne.
    public func run() async {
        await runner.run()
    }

    /// Lit le jour et le suit en direct jusqu'à la fin du flux ou l'annulation (le jour affiché
    /// reste en place).
    private func follow() async {
        if case .loaded = phase { isRefreshing = true } else { phase = .loading }
        defer { isRefreshing = false }
        let client = client ?? Idalgo.client
        var received = false
        do {
            for try await day in client.scoreCenterUpdates(
                sport: sport, date: date, competitions: competitions, timeZone: timeZone
            ) {
                phase = .loaded(day)
                isRefreshing = false
                received = true
            }
        } catch is CancellationError {
            return
        } catch {
            // Après un jour lu, le dernier reste à l'écran.
            if received || Task.isCancelled { return }
            phase = .failed(error as? IdalgoError ?? .network(code: nil, message: error.localizedDescription))
        }
    }
}
