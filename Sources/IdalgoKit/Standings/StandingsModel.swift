import SwiftUI

/// État du composant Classement : lecture (saison, compétition ou classements déjà lus), choix du
/// split et de la poule.
@MainActor
final class StandingsModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded(StandingsPresentation)
        case unsupported
        case failed(IdalgoError)
    }

    /// D'où vient le classement.
    enum Source: Equatable {
        case season(String)
        /// Saison en cours d'une compétition (`currentSeason.id`), résolue par le client.
        case competition(String)
        /// Classements déjà lus, par split (feuille de match) : rien n'est demandé à l'API.
        case preloaded([StandingSplit: Standings])
    }

    /// Ce qui déclenche une nouvelle lecture.
    struct Request: Equatable {
        let source: Source
        let group: String?
        let split: StandingSplit
        let attempt: Int
    }

    @Published private(set) var phase: Phase = .loading
    /// Une lecture est en cours alors qu'un classement est déjà affiché (changement de split).
    @Published private(set) var isRefreshing = false
    @Published var split: StandingSplit
    @Published var selectedGroupID: String?
    @Published private(set) var attempt = 0

    init(split: StandingSplit) {
        self.split = split
    }

    /// Splits proposés au lecteur : tous, ou ceux des classements déjà lus.
    static func splits(for source: Source) -> [StandingSplit] {
        guard case let .preloaded(standings) = source else { return StandingSplit.allCases }
        return StandingSplit.allCases.filter { standings[$0] != nil }
    }

    func request(_ source: Source, group: String?) -> Request {
        Request(source: source, group: group, split: split, attempt: attempt)
    }

    func retry() {
        attempt += 1
    }

    func load(_ request: Request, client: IdalgoClient, highlight: Set<String>) async {
        if case .loaded = phase { isRefreshing = true } else { phase = .loading }
        defer { isRefreshing = false }
        do {
            let standings = try await Self.standings(for: request, client: client)
            guard let presentation = StandingsPresentation(standings) else {
                phase = .unsupported
                return
            }
            selectGroup(in: presentation, highlight: highlight)
            phase = .loaded(presentation)
        } catch is CancellationError {
            return
        } catch let error as IdalgoError {
            phase = .failed(error)
        } catch {
            phase = .failed(.network(code: nil, message: error.localizedDescription))
        }
    }

    static func standings(for request: Request, client: IdalgoClient) async throws -> Standings {
        switch request.source {
        case let .preloaded(standings):
            guard let standings = standings[request.split] ?? standings[.overall] else {
                throw IdalgoError.api(status: 404, code: nil, detail: nil)
            }
            return standings
        case let .season(season):
            return try await client.standings(season: season, group: request.group, split: request.split)
        case let .competition(competition):
            let season = try await client.currentSeasonID(competition: competition)
            return try await client.standings(season: season, group: request.group, split: request.split)
        }
    }

    /// Garde la poule choisie si elle existe encore ; sinon la première qui contient une équipe
    /// mise en avant, ou la première.
    private func selectGroup(in presentation: StandingsPresentation, highlight: Set<String>) {
        let groups = presentation.groups
        if let selectedGroupID, groups.contains(where: { $0.id == selectedGroupID }) { return }
        selectedGroupID = StandingsPresentation.Group.preferred(in: groups, highlight: highlight, id: nil)?.id
    }
}

extension StandingsPresentation.Group {
    /// La poule `id` si elle existe, sinon la première qui contient une équipe mise en avant, ou la
    /// première.
    static func preferred(in groups: [Self], highlight: Set<String>, id: String?) -> Self? {
        groups.first { $0.id == id }
            ?? groups.first { $0.rows.contains { highlight.contains($0.id) } }
            ?? groups.first
    }
}
