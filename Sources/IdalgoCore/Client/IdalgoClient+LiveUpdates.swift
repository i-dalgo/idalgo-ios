import Foundation

extension IdalgoClient {
    /// Le Score Center d'un jour, puis le même jour après chaque lecture du direct.
    ///
    /// Le flux lit le module et le transmet ; s'il y a des matchs en cours ou à venir ce jour-là,
    /// il relit `/live` à partir de 90 minutes avant le premier coup d'envoi (tout de suite si un
    /// match est en cours), reporte chaque lecture sur le jour (`ScoreCenter.applying(_:)`) et
    /// transmet le jour mis à jour, au rythme de `pollAfter`. Il se termine quand plus rien ne
    /// bougera. Une erreur passagère pendant le direct est réessayée après 30 s sans finir le flux ;
    /// une erreur à la première lecture, ou permanente, le termine en échec.
    ///
    /// Cesser de lire le flux (tâche annulée, vue disparue) arrête les requêtes ; le relire relit
    /// le module aussitôt. En SwiftUI, lisez-le dans `.task(id:)`, relancé au retour au premier plan :
    ///
    /// ```swift
    /// .task(id: scenePhase == .active) {
    ///     guard scenePhase == .active else { return }
    ///     do {
    ///         for try await day in Idalgo.client.scoreCenterUpdates(sport: "102") { self.day = day }
    ///     } catch { self.error = error }
    /// }
    /// ```
    public func scoreCenterUpdates(
        sport: String,
        date: String? = nil,
        competitions: [String] = [],
        timeZone: String? = nil
    ) -> AsyncThrowingStream<ScoreCenter, Error> {
        LiveStream.make(
            buffering: liveBuffering,
            now: now,
            sleep: sleep,
            load: { try await self.scoreCenter(sport: sport, date: date, competitions: competitions, timeZone: timeZone) },
            startDelay: { day, now in LiveSchedule.firstStartDelay(for: day.allContests, now: now) },
            fetchLive: { day in
                // Le jour lu (et son fuseau), même quand `date` vaut « aujourd'hui ».
                try await self.scoreCenterLive(sport: sport, date: day.date, competitions: competitions, timeZone: day.timeZone)
            },
            merge: { day, live in day.applying(live) }
        )
    }

    /// La feuille d'un match, puis la même feuille après chaque lecture du direct.
    ///
    /// Le flux lit le module et le transmet ; pour un match en cours ou à venir, il relit `/live`
    /// à partir de 90 minutes avant le coup d'envoi (tout de suite pendant le match), remplace
    /// en-tête, actions et compositions (`MatchSheet.applying(_:)`) et transmet la feuille au
    /// rythme de `pollAfter`. Mêmes règles de fin, d'erreurs et d'annulation que
    /// `scoreCenterUpdates`.
    public func matchSheetUpdates(contest: String) -> AsyncThrowingStream<MatchSheet, Error> {
        LiveStream.make(
            buffering: liveBuffering,
            now: now,
            sleep: sleep,
            load: { try await self.matchSheet(contest: contest) },
            startDelay: { sheet, now in
                LiveSchedule.startDelay(status: sheet.contest.status, startsAt: sheet.contest.startsAt, now: now)
            },
            fetchLive: { _ in try await self.matchSheetLive(contest: contest) },
            merge: { sheet, live in sheet.applying(live) }
        )
    }
}
