import Foundation

enum GameMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case reverse
    case upAndBack

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .reverse: "Reverse"
        case .upAndBack: "Up & Back"
        }
    }

    var subtitle: String {
        switch self {
        case .standard: "3 cards to 10"
        case .reverse: "10 cards to 3"
        case .upAndBack: "3 to 10 and back"
        }
    }

    var rounds: [Int] {
        switch self {
        case .standard: Array(3...10)
        case .reverse: Array((3...10).reversed())
        case .upAndBack: Array(3...10) + Array((3...9).reversed())
        }
    }
}

struct Player: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct RoundScore: Codable, Identifiable, Hashable {
    let id: UUID
    let playerID: UUID
    let roundIndex: Int
    var points: Int

    init(id: UUID = UUID(), playerID: UUID, roundIndex: Int, points: Int) {
        self.id = id
        self.playerID = playerID
        self.roundIndex = roundIndex
        self.points = points
    }
}

struct Game: Codable, Identifiable, Hashable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var mode: GameMode
    var players: [Player]
    var currentRoundIndex: Int
    var scores: [RoundScore]
    var roundDrafts: [Int: [UUID: String]]?

    init(id: UUID = UUID(), createdAt: Date = .now, updatedAt: Date = .now, completedAt: Date? = nil, mode: GameMode, players: [Player], currentRoundIndex: Int = 0, scores: [RoundScore] = []) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.mode = mode
        self.players = players
        self.currentRoundIndex = currentRoundIndex
        self.scores = scores
        self.roundDrafts = nil
    }

    var isComplete: Bool { completedAt != nil }
    var currentCardCount: Int { mode.rounds[min(currentRoundIndex, mode.rounds.count - 1)] }
    var roundNumber: Int { min(currentRoundIndex + 1, mode.rounds.count) }

    func score(for playerID: UUID, roundIndex: Int) -> Int? {
        scores.first { $0.playerID == playerID && $0.roundIndex == roundIndex }?.points
    }

    func total(for playerID: UUID) -> Int {
        scores
            .filter { $0.playerID == playerID }
            .reduce(0) { total, score in
                total + score.points
            }
    }

    var rankedPlayers: [Player] {
        players.sorted {
            let left = total(for: $0.id)
            let right = total(for: $1.id)
            return left == right ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : left > right
        }
    }

    var leaders: [Player] {
        guard let best = players.map({ total(for: $0.id) }).max() else { return [] }
        return players.filter { total(for: $0.id) == best }
    }
}

enum AppTab: Hashable {
    case games
    case dictionary
}

enum AppRoute: Hashable {
    case setup
    case game(UUID)
    case history
}
