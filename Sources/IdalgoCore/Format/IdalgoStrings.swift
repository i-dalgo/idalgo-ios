import Foundation

/// Libellés des composants, en français, réunis ici pour une traduction future.
package enum IdalgoStrings {
    // MARK: Classement
    package static let positionHeader = "#"
    package static let teamHeader = "Équipe"
    package static let splitPicker = "Vue du classement"
    package static let groupPicker = "Poule"
    package static let standingsUnavailable = "Classement indisponible"
    package static let standingsEmpty = "Aucun classement disponible"
    package static let standingsUnsupported = "Ce classement n'est pas encore pris en charge"
    package static let competitionNotFound = "Cette compétition n'existe pas."
    package static let noCurrentSeason = "Cette compétition n'a pas de saison en cours."
    package static let standingsGap = "Lignes masquées"
    package static let retry = "Réessayer"
    package static let loading = "Chargement du classement"
    package static let highlighted = "mis en avant"

    package static func split(_ split: StandingSplit) -> String {
        switch split {
        case .overall: "Général"
        case .home: "Domicile"
        case .away: "Extérieur"
        }
    }

    /// Nom d'une poule sans nom, numérotée à partir de 1.
    package static func unnamedGroup(_ number: Int) -> String { "Poule \(number)" }

    /// « Après le 7 novembre 2026 ».
    package static func afterDay(_ day: String) -> String { "Après le \(day)" }

    // MARK: Erreurs

    package static let networkError = "Vérifiez votre connexion internet."
    /// Erreur du serveur sans explication lisible, par écran.
    package static let standingsLoadFailed = "Le classement n'a pas pu être chargé."
    package static let scoreCenterLoadFailed = "Les matchs de ce jour n'ont pas pu être chargés."
    package static let matchSheetLoadFailed = "La feuille de ce match n'a pas pu être chargée."
    package static let decodingError = "La réponse du serveur est inattendue."

    // MARK: Accessibilité

    package static func placesGained(_ count: Int) -> String { "gagne \(plural(count, "place"))" }
    package static func placesLost(_ count: Int) -> String { "perd \(plural(count, "place"))" }

    /// Ordinal français : 1er, 2e, 3e…
    package static func ordinal(_ number: Int) -> String { number == 1 ? "1er" : "\(number)e" }

    /// « 0 point », « 1 point », « 2 points » : singulier jusqu'à 1 en français.
    package static func plural(_ count: Int, _ singular: String) -> String {
        "\(count) \(singular)\(abs(count) > 1 ? "s" : "")"
    }

    // MARK: Score Center
    package static let scoreCenterUnavailable = "Matchs indisponibles"
    package static let scoreCenterLoading = "Chargement des matchs"
    package static let statusFilter = "Statut des matchs"
    package static let previousDay = "Jour précédent avec des matchs"
    package static let nextDay = "Jour suivant avec des matchs"
    package static let today = "Aujourd'hui"
    package static let yesterday = "Hier"
    package static let tomorrow = "Demain"
    package static let standings = "Classement"
    package static let close = "Fermer"
    package static let moreContests = "D'autres matchs de ce jour ne sont pas affichés."
    package static let finished = "Terminé"
    package static let postponed = "Reporté"
    package static let cancelled = "Annulé"
    package static let live = "En direct"

    /// Libellé d'un filtre de statut et message d'un jour sans match pour ce filtre.
    package static func filter(_ filter: IdalgoStatusFilter) -> (tab: String, empty: String) {
        switch filter {
        case .all: ("Tous", "Aucun match ce jour-là.")
        case .live: ("En cours", "Aucun match en cours ce jour-là.")
        case .finished: ("Terminés", "Aucun match terminé ce jour-là.")
        case .scheduled: ("À venir", "Aucun match à venir ce jour-là.")
        }
    }

    /// « Journée 9 ».
    package static func matchday(_ number: Int) -> String { "Journée \(number)" }

    /// Lecture d'un match par VoiceOver : « Paris SG 2, Lyon 1, terminé ».
    static func contestScore(home: String, homeScore: String, away: String, awayScore: String) -> String {
        "\(home) \(homeScore), \(away) \(awayScore)"
    }

    /// « Danemark contre Norvège ».
    static func versus(_ home: String, _ away: String) -> String { "\(home) contre \(away)" }

    /// « à 21 h 45 ».
    static func kickoffSpoken(hour: Int, minute: Int) -> String {
        minute == 0 ? "à \(hour) h" : "à \(hour) h \(String(format: "%02d", minute))"
    }

    static let spokenLive = "en cours"
    static let spokenFinished = "terminé"
    static let spokenPostponed = "reporté"
    static let spokenCancelled = "annulé"

    // MARK: Feuille de match
    package static let matchSheet = "Feuille de match"
    package static let matchSheetUnavailable = "Feuille de match indisponible"
    package static let matchSheetLoading = "Chargement de la feuille de match"
    package static let sections = "Rubriques de la feuille de match"
    package static let upcoming = "À venir"
    package static let halfTime = "Mi-temps"
    package static let fullTime = "Fin du match"
    package static let noActions = "Pas encore d'action pour ce match."
    package static let noLineups = "Compositions pas encore connues."
    package static let noPreview = "Pas encore d'avant-match pour ce match."
    package static let lineupTeam = "Équipe affichée"
    package static let coach = "Entraîneur"
    package static let substitutes = "Remplaçants"
    package static let notOnPitch = "Autres titulaires"
    package static let form = "Forme"
    package static let keyPlayers = "Joueurs clés"
    package static let headToHead = "Confrontations"
    package static let lastMeetings = "Dernières confrontations"
    package static let firstMeeting = "Première confrontation entre ces deux équipes."
    package static let draws = "Nuls"
    package static let averageGoals = "Buts par match"
    package static let scoreless = "Matchs sans but"
    package static let frequentScore = "Score le plus fréquent"
    package static let competition = "Compétition"
    package static let phase = "Phase"
    package static let date = "Date"
    package static let venue = "Stade"
    package static let capacity = "Capacité"
    package static let audience = "Affluence"
    package static let referee = "Arbitre"
    package static let captain = "capitaine"

    package static func tab(_ tab: MatchSheetTab) -> String {
        switch tab {
        case .info: "Infos"
        case .actions: "Actions"
        case .lineups: "Compos"
        case .preview: "Avant-match"
        }
    }

    /// « mi-temps 0 – 0 ».
    static func halfTimeScore(_ home: String, _ away: String) -> String { "mi-temps \(home) – \(away)" }
    static func places(_ count: String) -> String { "\(count) places" }
    static func spectators(_ count: String) -> String { "\(count) spectateurs" }
    static func wins(_ team: String) -> String { "Victoires \(team)" }
    /// « samedi 10 octobre 2026 à 15:30 ».
    static func dateAtTime(_ day: String, _ time: String) -> String { "\(day) à \(time)" }

    /// Ce que dit VoiceOver d'une action, sans l'auteur.
    static func spokenAction(_ kind: ActionKind) -> String {
        switch kind {
        case .goal: "but"
        case .ownGoal: "but contre son camp"
        case .yellowCard: "carton jaune"
        case .secondYellowCard: "deuxième carton jaune"
        case .redCard: "carton rouge"
        case .substitution: "remplacement"
        case .shootoutScored: "tir au but réussi"
        case .shootoutMissed: "tir au but manqué"
        case let .other(label): label
        }
    }

    static func spokenMinute(_ minute: Int) -> String { minute == 1 ? "1re minute" : "\(minute)e" }
    static func by(_ what: String, _ person: String) -> String { "\(what) de \(person)" }
    static func substitution(entering: String, leaving: String?) -> String {
        leaving.map { "entrée de \(entering), sortie de \($0)" } ?? "entrée de \(entering)"
    }

    /// Libellé court d'un résultat de la forme : V, N, D.
    static func formLetter(_ result: FormResult) -> String {
        switch result {
        case .win: "V"
        case .draw: "N"
        case .loss: "D"
        }
    }

    static func formResult(_ result: FormResult) -> String {
        switch result {
        case .win: "Victoire"
        case .draw: "Nul"
        case .loss: "Défaite"
        }
    }

    static func against(_ opponent: String) -> String { "contre \(opponent)" }

    static let weekdays = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

    static let months = [
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre",
    ]
}
