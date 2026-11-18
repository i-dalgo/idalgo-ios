/// Ce que la feuille dessine pour une action.
package enum ActionKind: Sendable, Equatable {
    case goal, ownGoal, yellowCard, secondYellowCard, redCard, substitution, shootoutScored, shootoutMissed
    /// Famille inconnue du SDK : son libellé, sans icône dédiée.
    case other(label: String)

    /// Compte au tableau d'affichage (un tir au but, non).
    var scores: Bool { self == .goal || self == .ownGoal }
}

/// Score au tableau d'affichage.
package struct MatchScore: Sendable, Equatable {
    package var home: Int
    package var away: Int

    package init(home: Int, away: Int) {
        self.home = home
        self.away = away
    }

    /// « 1 – 0 ».
    package var text: String { "\(home) – \(away)" }
}

/// Une ligne du fil des actions.
package enum TimelineRow: Sendable, Equatable, Identifiable {
    /// Une action, et le score juste après pour un but.
    case action(ContestAction, kind: ActionKind, score: MatchScore?)
    /// Coupure entre deux périodes (« Mi-temps ») ou fin du match, avec le score à ce moment-là.
    case pause(label: String, score: MatchScore)

    package var id: String {
        switch self {
        case let .action(action, _, _): action.id
        case let .pause(label, _): "pause-\(label)"
        }
    }
}

/// Un buteur pour l'en-tête.
package struct Scorer: Sendable, Equatable, Identifiable {
    package let id: String
    package let personId: String?
    package let name: String
    package let minute: String
    package let ownGoal: Bool
    package let penalty: Bool

    /// « Calafiori 62’ », « Saka 45’ (pen.) », « Justin 56’ (c.s.c.) ».
    package var label: String {
        let suffix = ownGoal ? " (c.s.c.)" : penalty ? " (pen.)" : ""
        return "\(name) \(minute)\(suffix)"
    }
}

/// Ce qui est arrivé à un joueur pendant le match.
package struct PlayerMarks: Sendable, Equatable {
    package var goals = 0
    package var ownGoals = 0
    package var yellowCards = 0
    package var redCard = false
    /// Minute de sortie (remplacé) ; `nil` s'il a fini le match.
    package var outAt: String?
    /// Entré en jeu : la minute et le joueur remplacé.
    package var inAt: Entry?

    /// Entrée en jeu d'un remplaçant.
    package struct Entry: Sendable, Equatable {
        package let minute: String
        package let replaced: String
    }
}

/// Lecture des actions d'un match (règles de `apps/ui-kit/src/utils/match-sheet.ts`).
package enum MatchActions {
    /// Ce que la feuille dessine pour une action ; `nil` pour une action qu'elle ne montre pas
    /// (tir, faute, passe…). Une famille inconnue se montre avec son libellé.
    package static func kind(of action: ContestAction) -> ActionKind? {
        switch action.family {
        case .goal: return .goal
        case .ownGoal: return .ownGoal
        case .card:
            switch action.type {
            case .secondYellowCard: return .secondYellowCard
            case .redCard: return .redCard
            default: return .yellowCard
            }
        case .substitution: return .substitution
        case .shootout: return action.type == .shootoutMissed ? .shootoutMissed : .shootoutScored
        default:
            guard !ActionFamily.known.contains(action.family.rawValue) else { return nil }
            return .other(label: action.label ?? action.type.rawValue)
        }
    }

    /// Le fil : actions dans l'ordre reçu, score après chaque but, une coupure à chaque changement
    /// de période (la première est « Mi-temps »), et « Fin du match » pour un match terminé. Les
    /// tirs au but ne comptent pas au score du match.
    package static func timeline(_ actions: [ContestAction], finished: Bool) -> [TimelineRow] {
        var rows: [TimelineRow] = []
        var score = MatchScore(home: 0, away: 0)
        var period: String?
        for action in actions {
            guard let kind = kind(of: action) else { continue }
            if let current = period, let next = action.period, next != current {
                let pauses = rows.filter { if case .pause = $0 { true } else { false } }.count
                rows.append(.pause(label: pauses == 0 ? IdalgoStrings.halfTime : current, score: score))
            }
            if let next = action.period { period = next }
            if kind.scores { score = after(score, action.side) }
            rows.append(.action(action, kind: kind, score: kind.scores ? score : nil))
        }
        if finished, !rows.isEmpty { rows.append(.pause(label: IdalgoStrings.fullTime, score: score)) }
        return rows
    }

    private static func after(_ score: MatchScore, _ side: Side?) -> MatchScore {
        var next = score
        switch side {
        case .home: next.home += 1
        case .away: next.away += 1
        case nil: break
        }
        return next
    }

    /// Les buteurs d'un camp, dans l'ordre du match ; un but contre son camp va au camp crédité.
    package static func scorers(_ actions: [ContestAction], side: Side) -> [Scorer] {
        actions.filter { kind(of: $0)?.scores == true && $0.side == side }.map { action in
            Scorer(
                id: action.id,
                personId: action.person?.id,
                name: MatchSheetFormat.lastName(action.person?.name),
                minute: MatchSheetFormat.minute(action.minute),
                ownGoal: action.family == .ownGoal,
                penalty: action.type == .penaltyGoal
            )
        }
    }

    /// Ce qui est arrivé à chaque joueur, par id : buts, cartons, remplacement.
    package static func playerMarks(_ actions: [ContestAction]) -> [String: PlayerMarks] {
        var marks: [String: PlayerMarks] = [:]
        for action in actions {
            guard let kind = kind(of: action), let person = action.person else { continue }
            switch kind {
            case .goal: marks[person.id, default: PlayerMarks()].goals += 1
            case .ownGoal: marks[person.id, default: PlayerMarks()].ownGoals += 1
            case .yellowCard: marks[person.id, default: PlayerMarks()].yellowCards += 1
            case .secondYellowCard, .redCard: marks[person.id, default: PlayerMarks()].redCard = true
            case .substitution:
                let minute = MatchSheetFormat.minute(action.minute)
                marks[person.id, default: PlayerMarks()].inAt = .init(minute: minute, replaced: MatchSheetFormat.lastName(action.relatedPerson?.name))
                if let leaving = action.relatedPerson { marks[leaving.id, default: PlayerMarks()].outAt = minute }
            case .shootoutScored, .shootoutMissed, .other: continue
            }
        }
        return marks
    }

    /// Lecture VoiceOver : « 67e, but de Bukayo Saka, Arsenal, 1 – 1 ».
    package static func accessibilityLabel(_ action: ContestAction, kind: ActionKind, score: MatchScore?, team: String?) -> String {
        let what = IdalgoStrings.spokenAction(kind)
        let detail: String = switch (kind, action.person?.name) {
        case let (.substitution, entering?): "\(what), \(IdalgoStrings.substitution(entering: entering, leaving: action.relatedPerson?.name))"
        case let (_, person?): IdalgoStrings.by(what, person)
        default: what
        }
        return [
            action.minute.map { IdalgoStrings.spokenMinute(Int($0.rounded())) },
            detail,
            team,
            score?.text,
        ].compactMap { $0 }.joined(separator: ", ")
    }
}
