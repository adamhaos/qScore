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

    var systemImage: String {
        switch self {
        case .standard: "arrow.up.right"
        case .reverse: "arrow.down.right"
        case .upAndBack: "arrow.up.and.down"
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
    /// Longest Word / Most Words bonuses awarded in each submitted round.
    /// Optional so games saved before bonuses existed still decode.
    var bonuses: [Int: RoundBonuses]?
    /// Bonus picks for a round that hasn't been saved yet.
    var bonusDrafts: [Int: RoundBonuses]?

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
        self.bonuses = nil
        self.bonusDrafts = nil
    }

    var isComplete: Bool { completedAt != nil }
    var currentCardCount: Int { mode.rounds[min(currentRoundIndex, mode.rounds.count - 1)] }
    var roundNumber: Int { min(currentRoundIndex + 1, mode.rounds.count) }

    /// Points typed in for a round, without bonuses.
    func basePoints(for playerID: UUID, roundIndex: Int) -> Int? {
        scores.first { $0.playerID == playerID && $0.roundIndex == roundIndex }?.points
    }

    func bonusPoints(for playerID: UUID, roundIndex: Int) -> Int {
        bonuses?[roundIndex]?.points(for: playerID) ?? 0
    }

    /// A player's full score for a round, including any bonuses.
    func score(for playerID: UUID, roundIndex: Int) -> Int? {
        guard let base = basePoints(for: playerID, roundIndex: roundIndex) else { return nil }
        return base + bonusPoints(for: playerID, roundIndex: roundIndex)
    }

    func total(for playerID: UUID) -> Int {
        scores
            .filter { $0.playerID == playerID }
            .reduce(0) { total, score in
                total + score.points + bonusPoints(for: playerID, roundIndex: score.roundIndex)
            }
    }

    /// Standard competition ranking, so tied players share a place (1, 1, 3).
    func rank(of playerID: UUID) -> Int {
        let score = total(for: playerID)
        return players.filter { total(for: $0.id) > score }.count + 1
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

enum RoundBonus: String, Codable, CaseIterable, Identifiable {
    case longestWord
    case mostWords

    static let points = 10

    var id: Self { self }

    var title: String {
        switch self {
        case .longestWord: "Longest Word"
        case .mostWords: "Most Words"
        }
    }

    var shortTitle: String {
        switch self {
        case .longestWord: "Longest"
        case .mostWords: "Most"
        }
    }

    var systemImage: String {
        switch self {
        case .longestWord: "ruler.fill"
        case .mostWords: "square.stack.3d.up.fill"
        }
    }
}

/// Who holds each bonus in a round. Each bonus can go to at most one player.
struct RoundBonuses: Codable, Hashable {
    var longestWord: UUID?
    var mostWords: UUID?

    subscript(bonus: RoundBonus) -> UUID? {
        get {
            switch bonus {
            case .longestWord: longestWord
            case .mostWords: mostWords
            }
        }
        set {
            switch bonus {
            case .longestWord: longestWord = newValue
            case .mostWords: mostWords = newValue
            }
        }
    }

    var isEmpty: Bool { longestWord == nil && mostWords == nil }

    func bonuses(for playerID: UUID) -> [RoundBonus] {
        RoundBonus.allCases.filter { self[$0] == playerID }
    }

    func points(for playerID: UUID) -> Int {
        bonuses(for: playerID).count * RoundBonus.points
    }

    /// Gives the bonus to the player, or takes it back if they already hold it.
    mutating func toggle(_ bonus: RoundBonus, for playerID: UUID) {
        self[bonus] = self[bonus] == playerID ? nil : playerID
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
