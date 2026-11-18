import Foundation

/// Quand commencer à relire une route live, d'après les contests affichés (règles des widgets
/// web, `apps/ui-kit/src/utils/live-contests.ts`). Ensuite, c'est `pollAfter` qui décide.
package enum LiveSchedule {
    /// Avance sur le coup d'envoi : les compositions sont publiées environ une heure avant.
    package static let leadTime: TimeInterval = 90 * 60
    /// Au-delà, l'écran sera fermé bien avant le match : rien n'est programmé.
    static let maxWait: TimeInterval = 24 * 60 * 60
    /// Un match encore « à venir » plus longtemps après son coup d'envoi est bloqué à la source.
    static let staleAfterKickoff: TimeInterval = 6 * 60 * 60

    /// Secondes avant de relire un contest : 0 pendant le match, l'heure des compositions avant ;
    /// `nil` s'il ne bougera plus (terminé, reporté, annulé, bloqué) ou pas avant longtemps.
    package static func startDelay(status: ContestStatus, startsAt: Date?, now: Date) -> TimeInterval? {
        if status == .live { return 0 }
        guard status == .scheduled, let startsAt else { return nil }
        let sinceKickoff = now.timeIntervalSince(startsAt)
        if sinceKickoff > staleAfterKickoff { return nil }
        let delay = -sinceKickoff - leadTime
        if delay > maxWait { return nil }
        return max(delay, 0)
    }

    /// Le plus proche des délais : une liste se relit dès qu'un de ses contests bouge.
    package static func firstStartDelay(for contests: [Contest], now: Date) -> TimeInterval? {
        contests
            .compactMap { contest in contest.status.flatMap { startDelay(status: $0, startsAt: contest.startsAt, now: now) } }
            .min()
    }
}
