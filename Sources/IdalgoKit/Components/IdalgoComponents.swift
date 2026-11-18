import SwiftUI

/// Les parties des composants iDalgo qu'une app peut remplacer, une à une, en gardant le reste :
/// la ligne d'un match, le bandeau d'une compétition, les états vide, erreur et chargement.
///
/// Chaque méthode a une version par défaut (celle du SDK) : n'écrivez que celles à changer, puis
/// posez l'ensemble avec `.idalgoComponents(_:)`. Chaque partie reçoit un objet d'options ; de
/// nouveaux champs pourront s'y ajouter sans casser votre code.
///
/// ```swift
/// struct MesComposants: IdalgoComponents {
///     func emptyState(_ options: IdalgoEmptyStateOptions) -> some View {
///         Label(options.message, systemImage: "calendar")
///     }
/// }
///
/// IdalgoScoreCenterView(sport: "102")
///     .idalgoComponents(MesComposants())
/// ```
@MainActor
public protocol IdalgoComponents {
    associatedtype ContestRow: View
    associatedtype CompetitionHeader: View
    associatedtype EmptyState: View
    associatedtype ErrorState: View
    associatedtype LoadingState: View

    /// Le contenu de la ligne d'un match (Score Center, `IdalgoScoreCenterSection`). Le SDK la rend
    /// touchable et pose le séparateur.
    @ViewBuilder func contestRow(_ options: IdalgoContestRowOptions) -> ContestRow
    /// Le bandeau d'un bloc de compétition du Score Center.
    @ViewBuilder func competitionHeader(_ options: IdalgoCompetitionHeaderOptions) -> CompetitionHeader
    /// Un état vide : jour sans match pour le filtre, classement vide, rubrique sans donnée.
    @ViewBuilder func emptyState(_ options: IdalgoEmptyStateOptions) -> EmptyState
    /// Une erreur de lecture, avec « Réessayer » quand une nouvelle tentative peut réussir.
    @ViewBuilder func errorState(_ options: IdalgoErrorStateOptions) -> ErrorState
    /// La première lecture en cours.
    @ViewBuilder func loadingState(_ options: IdalgoLoadingStateOptions) -> LoadingState
}

extension IdalgoComponents {
    /// La ligne du SDK (`IdalgoContestRow`).
    public func contestRow(_ options: IdalgoContestRowOptions) -> some View {
        ContestRowView(row: options.row)
    }

    /// Le bandeau du SDK : logo, nom, journée et bouton « Classement ».
    public func competitionHeader(_ options: IdalgoCompetitionHeaderOptions) -> some View {
        CompetitionHeaderView(options: options)
    }

    /// Le message centré du SDK.
    public func emptyState(_ options: IdalgoEmptyStateOptions) -> some View {
        MessageStateView(message: options.message)
    }

    /// Le message d'erreur du SDK, et « Réessayer ».
    public func errorState(_ options: IdalgoErrorStateOptions) -> some View {
        ErrorStateView(title: options.title, message: options.message, retry: options.retry)
    }

    /// Le squelette du SDK.
    public func loadingState(_ options: IdalgoLoadingStateOptions) -> some View {
        SkeletonTableView(rows: options.rows).accessibilityLabel(options.label)
    }
}

/// Les composants du SDK, sans remplacement.
public struct IdalgoDefaultComponents: IdalgoComponents {
    /// Les composants du SDK.
    public init() {}
}

/// Options de la ligne d'un match.
public struct IdalgoContestRowOptions {
    /// Le match.
    public let contest: Contest
    /// Fuseau de l'heure affichée.
    public let timeZone: TimeZone
    /// La ligne prête à afficher (noms, score, état, libellé VoiceOver).
    let row: ScoreCenterPresentation.Row
}

/// Options du bandeau d'une compétition.
public struct IdalgoCompetitionHeaderOptions {
    /// La compétition du bloc.
    public let competition: CompetitionRef
    /// Saison du bloc : celle du classement.
    public let season: SeasonRef
    /// Nom affiché (compétition, à défaut saison).
    public let title: String
    /// « Journée 9 », à défaut le nom de la phase.
    public let subtitle: String?
    /// Logo de la compétition (football).
    public let logo: Logo?
    /// Le bloc ouvre un classement (pas en phase à élimination, et `showsStandingsButton` vrai).
    public let showsStandingsButton: Bool
    /// Ouvre le classement de la saison (par le routeur de l'app, sinon dans une feuille).
    public let openStandings: () -> Void
}

/// Options d'un état vide.
public struct IdalgoEmptyStateOptions {
    /// Message en français (« Aucun match en cours ce jour-là. »).
    public let message: String
}

/// Options d'un état d'erreur.
public struct IdalgoErrorStateOptions {
    /// L'erreur de lecture.
    public let error: IdalgoError
    /// « Matchs indisponibles ».
    public let title: String
    /// Explication pour le lecteur (détail de l'API, ou message de l'écran).
    public let message: String
    /// Nouvelle tentative ; `nil` quand elle échouerait encore (`IdalgoError.isRetryable`).
    public let retry: (() -> Void)?
}

/// Options de l'état de chargement.
public struct IdalgoLoadingStateOptions {
    /// Libellé VoiceOver (« Chargement des matchs »).
    public let label: String
    /// Lignes du squelette par défaut.
    let rows: Int
}

/// Les composants de l'app, gardés dans l'environnement ; `nil` : ceux du SDK (sans `AnyView`).
struct ComponentsBox: @unchecked Sendable {
    let value: (any IdalgoComponents)?

    /// Les composants de l'app ; ceux du SDK sont gardés comme `nil`, rendus sans `AnyView`.
    init(_ components: (any IdalgoComponents)?) {
        value = components is IdalgoDefaultComponents ? nil : components
    }
}

private struct ComponentsKey: EnvironmentKey {
    static let defaultValue = ComponentsBox(nil)
}

extension EnvironmentValues {
    var idalgoComponentsBox: ComponentsBox {
        get { self[ComponentsKey.self] }
        set { self[ComponentsKey.self] = newValue }
    }
}

extension View {
    /// Remplace des parties des composants iDalgo de cette vue et de ses enfants (voir
    /// `IdalgoComponents`). Les écrans ouverts par le SDK (feuille de match, classement) les
    /// reçoivent aussi.
    public func idalgoComponents(_ components: some IdalgoComponents) -> some View {
        environment(\.idalgoComponentsBox, ComponentsBox(components))
    }
}

// MARK: - Emplacements

/// Les parties d'un ensemble posé par l'app, effacées : l'ensemble n'est connu que par son protocole.
extension IdalgoComponents {
    func erasedContestRow(_ options: IdalgoContestRowOptions) -> AnyView { AnyView(contestRow(options)) }
    func erasedCompetitionHeader(_ options: IdalgoCompetitionHeaderOptions) -> AnyView { AnyView(competitionHeader(options)) }
    func erasedEmptyState(_ options: IdalgoEmptyStateOptions) -> AnyView { AnyView(emptyState(options)) }
    func erasedErrorState(_ options: IdalgoErrorStateOptions) -> AnyView { AnyView(errorState(options)) }
    func erasedLoadingState(_ options: IdalgoLoadingStateOptions) -> AnyView { AnyView(loadingState(options)) }
}

/// Une partie : celle de l'app si elle en a posé, sinon celle du SDK, rendue sans effacement de type.
struct ContestRowSlot: View {
    let options: IdalgoContestRowOptions
    @Environment(\.idalgoComponentsBox) private var components

    var body: some View {
        if let custom = components.value {
            custom.erasedContestRow(options)
        } else {
            ContestRowView(row: options.row)
        }
    }
}

struct CompetitionHeaderSlot: View {
    let options: IdalgoCompetitionHeaderOptions
    @Environment(\.idalgoComponentsBox) private var components

    var body: some View {
        if let custom = components.value {
            custom.erasedCompetitionHeader(options)
        } else {
            CompetitionHeaderView(options: options)
        }
    }
}

struct EmptyStateSlot: View {
    let message: String
    @Environment(\.idalgoComponentsBox) private var components

    var body: some View {
        if let custom = components.value {
            custom.erasedEmptyState(IdalgoEmptyStateOptions(message: message))
        } else {
            MessageStateView(message: message)
        }
    }
}

struct ErrorStateSlot: View {
    let error: IdalgoError
    let title: String
    let fallback: String
    let retry: () -> Void
    @Environment(\.idalgoComponentsBox) private var components

    var body: some View {
        let options = IdalgoErrorStateOptions(
            error: error,
            title: title,
            message: error.readerMessage(fallback: fallback),
            retry: error.isRetryable ? retry : nil
        )
        if let custom = components.value {
            custom.erasedErrorState(options)
        } else {
            ErrorStateView(title: options.title, message: options.message, retry: options.retry)
        }
    }
}

struct LoadingStateSlot: View {
    let label: String
    var rows = 8
    @Environment(\.idalgoComponentsBox) private var components

    var body: some View {
        if let custom = components.value {
            custom.erasedLoadingState(IdalgoLoadingStateOptions(label: label, rows: rows))
        } else {
            SkeletonTableView(rows: rows).accessibilityLabel(label)
        }
    }
}
