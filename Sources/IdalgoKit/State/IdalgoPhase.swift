import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Où en est la lecture d'un document : en cours, lu (et suivi en direct), ou en échec.
public enum IdalgoPhase<Value: Sendable & Hashable>: Sendable, Hashable {
    /// Première lecture en cours.
    case loading
    /// Document lu ; il est remplacé à chaque lecture du direct.
    case loaded(Value)
    /// La première lecture a échoué ; `IdalgoError.isRetryable` dit si `retry()` peut aider.
    case failed(IdalgoError)

    /// Le document lu, s'il y en a un.
    public var value: Value? {
        if case let .loaded(value) = self { return value }
        return nil
    }
}

/// Ce qui est commun aux deux états publics : `run()` suivi par un ou plusieurs lecteurs, la
/// lecture (re)lancée à chaque changement d'entrée, suspendue quand l'app passe en arrière-plan.
@MainActor
final class LiveRunner {
    /// Lecteurs en cours de `run()` : la lecture tourne tant qu'il y en a un.
    private(set) var runners = 0
    private var task: Task<Void, Never>?
    private(set) var isAppActive = true
    private var observers: [NSObjectProtocol] = []
    private let follow: @MainActor () async -> Void

    init(follow: @escaping @MainActor () async -> Void) {
        self.follow = follow
    }

    /// Une lecture tourne-t-elle ?
    var isFollowing: Bool { task != nil }

    /// Suit le document jusqu'à l'annulation de la tâche appelante.
    func run() async {
        runners += 1
        if runners == 1 {
            observeApp()
            restart()
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
        runners -= 1
        if runners == 0 {
            task?.cancel()
            task = nil
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
        }
    }

    /// Relance la lecture (entrée changée, nouvelle tentative) si quelqu'un suit le document.
    func restart() {
        task?.cancel()
        guard runners > 0, isAppActive else {
            task = nil
            return
        }
        task = Task { await follow() }
    }

    /// Lecture suspendue en arrière-plan, reprise aussitôt au retour.
    func setAppActive(_ active: Bool) {
        guard active != isAppActive else { return }
        isAppActive = active
        restart()
    }

    private func observeApp() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setAppActive(false) }
            },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setAppActive(true) }
            },
        ]
        #endif
    }
}
