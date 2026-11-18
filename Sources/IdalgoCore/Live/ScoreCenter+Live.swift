extension ScoreCenter {
    /// Le jour avec une lecture live reportée sur ses duels, par `id` : statut, libellé, heure et
    /// scores. Une épreuve classée ou un contest absent du jour restent tels quels.
    public func applying(_ live: ScoreCenterLive) -> ScoreCenter {
        var updates: [String: LiveHeadToHead] = [:]
        for case let .headToHead(entry) in live.contests {
            updates[entry.id] = entry
        }
        guard !updates.isEmpty else { return self }
        var copy = self
        for blockIndex in copy.competitions.indices {
            copy.competitions[blockIndex].contests = copy.competitions[blockIndex].contests.map { contest in
                guard case var .headToHead(duel) = contest, let update = updates[duel.id] else { return contest }
                duel.status = update.status
                duel.statusLabel = update.statusLabel
                duel.startsAt = update.startsAt
                duel.home.score = update.home.score
                duel.away.score = update.away.score
                return .headToHead(duel)
            }
        }
        return copy
    }

    /// Tous les contests du jour, blocs mis bout à bout.
    public var allContests: [Contest] {
        competitions.flatMap(\.contests)
    }
}
