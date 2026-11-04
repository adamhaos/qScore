import SwiftUI

struct GameView: View {
    @Environment(GameStore.self) private var store
    let gameID: UUID
    @State private var scoreText: [UUID: String] = [:]
    @State private var displayedRoundIndex: Int?
    @State private var showingStandings = false

    private var game: Game? { store.game(withID: gameID) }
    private var visibleRoundNumber: Int {
        (displayedRoundIndex ?? game?.currentRoundIndex ?? 0) + 1
    }

    var body: some View {
        ZStack {
            QBackground()
            if let game {
                if game.isComplete {
                    CompletedGameView(game: game)
                } else {
                    activeGame(game)
                }
            }
        }
        .navigationTitle(game?.isComplete == true ? "Game Results" : "Round \(visibleRoundNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if game?.isComplete == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingStandings = true } label: { Label("Standings", systemImage: "list.number") }
                }
            }
        }
        .sheet(isPresented: $showingStandings) {
            if let game {
                StandingsView(game: game).presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            if let game, !game.isComplete {
                loadRound(displayedRoundIndex ?? game.currentRoundIndex, in: game)
            }
        }
    }

    private func activeGame(_ game: Game) -> some View {
        let roundIndex = displayedRoundIndex ?? game.currentRoundIndex
        let isReviewingRound = roundIndex < game.currentRoundIndex

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(game.mode.rounds[roundIndex])")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(QTheme.ink)
                    Text("CARDS THIS ROUND")
                        .font(.caption.bold()).tracking(1.6).foregroundStyle(.secondary)
                    ProgressView(value: Double(roundIndex + 1), total: Double(game.mode.rounds.count))
                        .tint(QTheme.sage).padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .qCard()

                roundControls(game: game, roundIndex: roundIndex, isReviewingRound: isReviewingRound)

                VStack(spacing: 12) {
                    ForEach(game.players) { player in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(player.name).font(.headline)
                                Text("Total: \(game.total(for: player.id))").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ScoreInputField(scores: scoreBinding(roundIndex: roundIndex), playerID: player.id)
                        }
                        if player.id != game.players.last?.id { Divider() }
                    }
                }
                .qCard()

                leaderBanner(game)
            }
            .padding()
        }
    }

    private func roundControls(game: Game, roundIndex: Int, isReviewingRound: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                showRound(roundIndex - 1, in: game)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .foregroundStyle(QTheme.sage)
                    .frame(width: 36, height: 36)
                    .background(QTheme.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .disabled(roundIndex == 0)
            .accessibilityLabel("Previous round")

            Button(
                isReviewingRound
                    ? "Update Round"
                    : (game.currentRoundIndex == game.mode.rounds.count - 1
                        ? "Finish Game"
                        : "Save Round & Continue")
            ) {
                saveRound(game, roundIndex: roundIndex)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .buttonStyle(.borderedProminent)
            .tint(QTheme.sage)
            .disabled(validatedPoints(in: game) == nil)

            Button {
                showRound(roundIndex + 1, in: game)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(QTheme.sage)
                    .frame(width: 36, height: 36)
                    .background(QTheme.sage.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .disabled(roundIndex >= game.currentRoundIndex)
            .accessibilityLabel("Next round")
        }
    }

    private func showRound(_ roundIndex: Int, in game: Game) {
        guard (0...game.currentRoundIndex).contains(roundIndex) else { return }
        displayedRoundIndex = roundIndex
        loadRound(roundIndex, in: game)
    }

    private func loadRound(_ roundIndex: Int, in game: Game) {
        scoreText = game.roundDrafts?[roundIndex] ?? game.players.reduce(into: [:]) { scores, player in
            if let points = game.score(for: player.id, roundIndex: roundIndex) {
                scores[player.id] = String(points)
            }
        }
    }

    private func scoreBinding(roundIndex: Int) -> Binding<[UUID: String]> {
        Binding(get: { scoreText }, set: { scores in
            scoreText = scores
            store.saveDraft(gameID: gameID, roundIndex: roundIndex, scores: scores)
        })
    }

    private func validatedPoints(in game: Game) -> [UUID: Int]? {
        var points: [UUID: Int] = [:]
        for player in game.players {
            guard let text = scoreText[player.id], let value = Int(text) else { return nil }
            points[player.id] = value
        }
        return points
    }

    private func saveRound(_ game: Game, roundIndex: Int) {
        guard let points = validatedPoints(in: game) else { return }

        if roundIndex < game.currentRoundIndex {
            store.updateRound(gameID: game.id, roundIndex: roundIndex, points: points)
        } else {
            store.submitRound(gameID: game.id, points: points)
            scoreText = [:]
            displayedRoundIndex = nil
        }
    }

    private func leaderBanner(_ game: Game) -> some View {
        HStack {
            Image(systemName: "crown.fill").foregroundStyle(QTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text(game.leaders.count == 1 ? "Current Leader" : "Currently Tied").font(.caption).foregroundStyle(.secondary)
                Text(game.leaders.map(\.name).joined(separator: " & ")).font(.headline).foregroundStyle(QTheme.ink)
            }
            Spacer()
            if let first = game.leaders.first {
                Text("\(game.total(for: first.id))").font(.title2.monospacedDigit().bold())
            }
        }
        .qCard()
    }

}

private struct ScoreInputField: View {
    @Binding var scores: [UUID: String]
    let playerID: UUID
    @State private var isShowingKeypad = false

    private var text: String {
        scores[playerID, default: ""]
    }

    var body: some View {
        Button {
            isShowingKeypad = true
        } label: {
            Text(text.isEmpty ? "--" : text)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .font(.title2.monospacedDigit().bold())
                .frame(width: 90, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(QTheme.cream, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Score")
        .accessibilityValue(text.isEmpty ? "Not entered" : text)
        .accessibilityHint("Opens the score keypad")
        .popover(isPresented: $isShowingKeypad, attachmentAnchor: .rect(.bounds)) {
            ScoreKeypad(scores: $scores, playerID: playerID)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct ScoreKeypad: View {
    @Binding var scores: [UUID: String]
    let playerID: UUID

    private var text: String {
        get { scores[playerID, default: ""] }
        nonmutating set { scores[playerID] = newValue }
    }

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { number in
                        keypadButton(String(number)) {
                            appendDigit(number)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                keypadButton(systemImage: "clear") {
                    text = ""
                }
                .accessibilityLabel("Clear score")

                keypadButton("0") {
                    appendDigit(0)
                }

                keypadButton(systemImage: "delete.left") {
                    if !text.isEmpty {
                        text.removeLast()
                    }
                }
                .accessibilityLabel("Delete")
            }

            Button(action: toggleSign) {
                Text("+/−")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Make score negative or positive")
        }
        .frame(width: 154, alignment: .center)
        .padding(10)
    }

    private func keypadButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.title3.monospacedDigit().bold())
            .frame(width: 46, height: 44)
            .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 10))
    }

    private func keypadButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 46, height: 44)
                .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func appendDigit(_ digit: Int) {
        guard text.count < 6 else { return }
        if text == "0" {
            text = String(digit)
        } else if text == "-0" {
            text = "-" + String(digit)
        } else {
            text.append(String(digit))
        }
    }

    private func toggleSign() {
        if text.hasPrefix("-") {
            text.removeFirst()
        } else {
            text = "-" + text
        }
    }

}

struct StandingsView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(game.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                HStack {
                    Text("\(index + 1)").font(.headline.monospacedDigit()).foregroundStyle(index == 0 ? QTheme.gold : .secondary).frame(width: 28)
                    Text(player.name)
                    Spacer()
                    Text("\(game.total(for: player.id))").font(.headline.monospacedDigit())
                }
            }
            .navigationTitle("Standings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}

struct CompletedGameView: View {
    let game: Game

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: "trophy.fill").font(.system(size: 58)).foregroundStyle(QTheme.gold).padding(.top, 18)
                Text(winnerTitle)
                    .font(.largeTitle.bold()).foregroundStyle(QTheme.ink)
                Text(game.mode.title + " • " + game.createdAt.formatted(date: .abbreviated, time: .omitted)).foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    ForEach(Array(game.rankedPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack {
                            Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 28)
                            Text(player.name).font(.headline)
                            Spacer()
                            Text("\(game.total(for: player.id))").font(.title3.monospacedDigit().bold())
                        }
                        .padding(.vertical, 12)
                        if player.id != game.rankedPlayers.last?.id { Divider() }
                    }
                }
                .qCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Round by Round").font(.headline)
                    ScrollView(.horizontal) {
                        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                            GridRow {
                                Text("Cards").font(.caption.bold())
                                ForEach(game.players) { Text($0.name).font(.caption.bold()).lineLimit(1) }
                            }
                            ForEach(game.mode.rounds.indices, id: \.self) { round in
                                GridRow {
                                    Text("\(game.mode.rounds[round])").foregroundStyle(.secondary)
                                    ForEach(game.players) { player in
                                        Text("\(game.score(for: player.id, roundIndex: round) ?? 0)").monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                }
                .qCard()
            }
            .padding()
        }
    }

    private var winnerTitle: String {
        guard let firstLeader = game.leaders.first else { return "Game Complete" }
        return game.leaders.count == 1 ? "\(firstLeader.name) Wins!" : "It’s a Tie!"
    }
}
