import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
    var games: [Game] = []
    var path: [AppRoute] = []
    var selectedTab: AppTab = .games
    var isShowingRules = false
    /// The game whose standings panel is showing, if any.
    var standingsGameID: UUID?

    private let saveURL: URL?

    init() {
        self.saveURL = Self.defaultSaveURL
        load()
    }

    init(saveURL: URL?) {
        self.saveURL = saveURL
        load()
    }

    var activeGames: [Game] {
        games.filter { !$0.isComplete }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var completedGames: [Game] {
        games.filter(\.isComplete).sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }

    func game(withID id: UUID) -> Game? {
        games.first { $0.id == id }
    }

    @discardableResult
    func createGame(mode: GameMode, playerNames: [String]) -> UUID {
        let players = playerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Player(name: $0) }
        let game = Game(mode: mode, players: players)
        games.append(game)
        persist()
        return game.id
    }

    func submitRound(gameID: UUID, points: [UUID: Int], bonuses: RoundBonuses? = nil) {
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }),
              !games[gameIndex].isComplete,
              games[gameIndex].players.allSatisfy({ points[$0.id] != nil }) else { return }
        let roundIndex = games[gameIndex].currentRoundIndex

        for player in games[gameIndex].players {
            guard let value = points[player.id] else { continue }
            if let scoreIndex = games[gameIndex].scores.firstIndex(where: {
                $0.playerID == player.id && $0.roundIndex == roundIndex
            }) {
                games[gameIndex].scores[scoreIndex].points = value
            } else {
                games[gameIndex].scores.append(RoundScore(playerID: player.id, roundIndex: roundIndex, points: value))
            }
        }

        games[gameIndex].roundDrafts?[roundIndex] = nil
        setBonuses(bonuses ?? RoundBonuses(), gameIndex: gameIndex, roundIndex: roundIndex)
        if roundIndex == games[gameIndex].mode.rounds.count - 1 {
            games[gameIndex].completedAt = .now
        } else {
            games[gameIndex].currentRoundIndex += 1
        }
        games[gameIndex].updatedAt = .now
        persist()
    }

    func updateRound(gameID: UUID, roundIndex: Int, points: [UUID: Int], bonuses: RoundBonuses? = nil) {
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }),
              roundIndex >= 0,
              roundIndex <= games[gameIndex].currentRoundIndex,
              (roundIndex < games[gameIndex].currentRoundIndex || games[gameIndex].isComplete),
              games[gameIndex].players.allSatisfy({ points[$0.id] != nil }) else { return }

        for player in games[gameIndex].players {
            guard let value = points[player.id] else { continue }
            if let scoreIndex = games[gameIndex].scores.firstIndex(where: {
                $0.playerID == player.id && $0.roundIndex == roundIndex
            }) {
                games[gameIndex].scores[scoreIndex].points = value
            } else {
                games[gameIndex].scores.append(
                    RoundScore(playerID: player.id, roundIndex: roundIndex, points: value)
                )
            }
        }

        games[gameIndex].roundDrafts?[roundIndex] = nil
        setBonuses(bonuses ?? RoundBonuses(), gameIndex: gameIndex, roundIndex: roundIndex)
        games[gameIndex].updatedAt = .now
        persist()
    }

    func saveDraft(gameID: UUID, roundIndex: Int, scores: [UUID: String]) {
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }),
              !games[gameIndex].isComplete,
              games[gameIndex].mode.rounds.indices.contains(roundIndex) else { return }
        if games[gameIndex].roundDrafts == nil {
            games[gameIndex].roundDrafts = [:]
        }
        games[gameIndex].roundDrafts?[roundIndex] = scores
        persist()
    }

    func saveBonusDraft(gameID: UUID, roundIndex: Int, bonuses: RoundBonuses) {
        guard let gameIndex = games.firstIndex(where: { $0.id == gameID }),
              !games[gameIndex].isComplete,
              games[gameIndex].mode.rounds.indices.contains(roundIndex) else { return }
        if games[gameIndex].bonusDrafts == nil {
            games[gameIndex].bonusDrafts = [:]
        }
        games[gameIndex].bonusDrafts?[roundIndex] = bonuses
        persist()
    }

    /// Stores a round's saved bonuses, dropping any player who isn't in the game.
    private func setBonuses(_ bonuses: RoundBonuses, gameIndex: Int, roundIndex: Int) {
        let playerIDs = Set(games[gameIndex].players.map(\.id))
        var cleaned = bonuses
        for bonus in RoundBonus.allCases where cleaned[bonus].map({ !playerIDs.contains($0) }) ?? false {
            cleaned[bonus] = nil
        }
        if games[gameIndex].bonuses == nil {
            games[gameIndex].bonuses = [:]
        }
        games[gameIndex].bonuses?[roundIndex] = cleaned.isEmpty ? nil : cleaned
        games[gameIndex].bonusDrafts?[roundIndex] = nil
    }

    func deleteGames(at offsets: IndexSet, from source: [Game]) {
        let ids = offsets.map { source[$0].id }
        games.removeAll { ids.contains($0.id) }
        persist()
    }

    func deleteGame(withID id: UUID) {
        games.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let saveURL,
              let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Game].self, from: data) else { return }
        games = decoded
    }

    private func persist() {
        guard let saveURL, let data = try? JSONEncoder().encode(games) else { return }
        try? FileManager.default.createDirectory(at: saveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: saveURL, options: .atomic)
    }

    private static var defaultSaveURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "qScore", directoryHint: .isDirectory)
            .appending(path: "games.json")
    }

    static var preview: GameStore {
        let store = GameStore(saveURL: nil)
        var active = Game(mode: .standard, players: [Player(name: "Adam"), Player(name: "Taylor")])
        for player in active.players {
            active.scores.append(RoundScore(playerID: player.id, roundIndex: 0, points: player.name == "Adam" ? 18 : 12))
        }
        active.currentRoundIndex = 1
        store.games = [active]
        return store
    }
}
