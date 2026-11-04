import SwiftUI

struct GameView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let gameID: UUID
    @State private var scoreText: [UUID: String] = [:]
    @State private var bonusDraft = RoundBonuses()
    @State private var displayedRoundIndex: Int?
    @State private var showingStandings = false
    @State private var finishedWhileOpen = false
    @State private var hasAppeared = false
    @State private var feedback: GameFeedback?
    @State private var feedbackTick = 0

    private var game: Game? { store.game(withID: gameID) }
    private var visibleRoundNumber: Int {
        (displayedRoundIndex ?? game?.currentRoundIndex ?? 0) + 1
    }

    var body: some View {
        ZStack {
            QBackground()
            if let game {
                if game.isComplete {
                    CompletedGameView(game: game, celebration: finishedWhileOpen ? .full : .quick)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    activeGame(game)
                        .transition(.opacity)
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
        .sensoryFeedback(.impact(weight: .light), trigger: showingStandings) { _, isShowing in isShowing }
        .sensoryFeedback(trigger: feedbackTick) { _, _ in feedback?.sensoryFeedback }
        .onAppear {
            if let game, !game.isComplete {
                loadRound(displayedRoundIndex ?? game.currentRoundIndex, in: game)
            }
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(QMotion.bouncy) { hasAppeared = true }
            }
        }
    }

    private func activeGame(_ game: Game) -> some View {
        let roundIndex = displayedRoundIndex ?? game.currentRoundIndex
        let isReviewingRound = roundIndex < game.currentRoundIndex
        let cardCount = game.mode.rounds[roundIndex]

        return ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("\(cardCount)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(QTheme.ink)
                        .contentTransition(.numericText(value: Double(cardCount)))
                    Text(isReviewingRound ? "CARDS · EDITING PAST ROUND" : "CARDS THIS ROUND")
                        .font(.caption.bold()).tracking(1.6).foregroundStyle(isReviewingRound ? QTheme.gold : .secondary)
                        .contentTransition(.opacity)
                    ProgressView(value: Double(roundIndex + 1), total: Double(game.mode.rounds.count))
                        .tint(QTheme.sage).padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .qCard()
                .scaleEffect(hasAppeared ? 1 : 0.92)
                .opacity(hasAppeared ? 1 : 0)

                roundControls(game: game, roundIndex: roundIndex, isReviewingRound: isReviewingRound)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(reduceMotion ? nil : QMotion.bouncy.delay(0.05), value: hasAppeared)

                VStack(spacing: 12) {
                    ForEach(Array(game.players.enumerated()), id: \.element.id) { index, player in
                        playerRow(player, in: game, roundIndex: roundIndex)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 14)
                            .animation(reduceMotion ? nil : QMotion.bouncy.delay(0.08 + Double(index) * 0.05), value: hasAppeared)
                        if player.id != game.players.last?.id { Divider() }
                    }
                }
                .qCard()

                leaderBanner(game)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(reduceMotion ? nil : QMotion.bouncy.delay(0.2), value: hasAppeared)
            }
            .padding()
        }
    }

    private func playerRow(_ player: Player, in game: Game, roundIndex: Int) -> some View {
        let total = game.total(for: player.id)
        let heldBonuses = bonusDraft.bonuses(for: player.id)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name).font(.headline)
                Text("Total: \(total)")
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(total)))
                if !heldBonuses.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(heldBonuses) { bonus in
                            BonusBadge(bonus: bonus)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        }
                    }
                    .transition(.opacity)
                }
            }
            Spacer()
            ScoreInputField(
                scores: scoreBinding(roundIndex: roundIndex),
                bonuses: bonusBinding(roundIndex: roundIndex),
                playerID: player.id,
                players: game.players
            )
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
            .buttonStyle(.pressable(scale: 0.9))
            .disabled(roundIndex == 0)
            .accessibilityLabel("Previous round")

            Button {
                saveRound(game, roundIndex: roundIndex)
            } label: {
                Text(
                    isReviewingRound
                        ? "Update Round"
                        : (game.currentRoundIndex == game.mode.rounds.count - 1
                            ? "Finish Game"
                            : "Save Round & Continue")
                )
                .contentTransition(.opacity)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
            }
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
            .buttonStyle(.pressable(scale: 0.9))
            .disabled(roundIndex >= game.currentRoundIndex)
            .accessibilityLabel("Next round")
        }
    }

    private func showRound(_ roundIndex: Int, in game: Game) {
        guard (0...game.currentRoundIndex).contains(roundIndex) else { return }
        withAnimation(reduceMotion ? nil : QMotion.snappy) {
            displayedRoundIndex = roundIndex
            loadRound(roundIndex, in: game)
        }
        sendFeedback(.roundChanged)
    }

    private func loadRound(_ roundIndex: Int, in game: Game) {
        scoreText = game.roundDrafts?[roundIndex] ?? game.players.reduce(into: [:]) { scores, player in
            if let points = game.basePoints(for: player.id, roundIndex: roundIndex) {
                scores[player.id] = String(points)
            }
        }
        bonusDraft = game.bonusDrafts?[roundIndex] ?? game.bonuses?[roundIndex] ?? RoundBonuses()
    }

    private func scoreBinding(roundIndex: Int) -> Binding<[UUID: String]> {
        Binding(get: { scoreText }, set: { scores in
            scoreText = scores
            store.saveDraft(gameID: gameID, roundIndex: roundIndex, scores: scores)
        })
    }

    private func bonusBinding(roundIndex: Int) -> Binding<RoundBonuses> {
        Binding(get: { bonusDraft }, set: { bonuses in
            bonusDraft = bonuses
            store.saveBonusDraft(gameID: gameID, roundIndex: roundIndex, bonuses: bonuses)
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
        let previousLeaders = Set(game.leaders.map(\.id))
        let isReviewingRound = roundIndex < game.currentRoundIndex
        let isFinalRound = !isReviewingRound && roundIndex == game.mode.rounds.count - 1

        withAnimation(reduceMotion ? nil : QMotion.snappy) {
            if isReviewingRound {
                store.updateRound(gameID: game.id, roundIndex: roundIndex, points: points, bonuses: bonusDraft)
            } else {
                if isFinalRound {
                    finishedWhileOpen = true
                }
                store.submitRound(gameID: game.id, points: points, bonuses: bonusDraft)
                displayedRoundIndex = nil
                if !isFinalRound, let updated = store.game(withID: game.id) {
                    loadRound(updated.currentRoundIndex, in: updated)
                } else {
                    scoreText = [:]
                    bonusDraft = RoundBonuses()
                }
            }
        }

        // The win celebration plays its own haptics.
        guard !isFinalRound else { return }
        let newLeaders = Set(store.game(withID: game.id)?.leaders.map(\.id) ?? [])
        if !newLeaders.isEmpty, newLeaders != previousLeaders {
            sendFeedback(.leaderChanged)
        } else {
            sendFeedback(isReviewingRound ? .roundUpdated : .roundSaved)
        }
    }

    private func sendFeedback(_ event: GameFeedback) {
        feedback = event
        feedbackTick += 1
    }

    private func leaderBanner(_ game: Game) -> some View {
        let leaderKey = game.leaders.map(\.id.uuidString).joined(separator: ",")
        let leadingTotal = game.leaders.first.map { game.total(for: $0.id) }

        return HStack {
            Image(systemName: "crown.fill")
                .foregroundStyle(QTheme.gold)
                .symbolEffect(.bounce, value: leaderKey)
            VStack(alignment: .leading, spacing: 2) {
                Text(game.leaders.count == 1 ? "Current Leader" : "Currently Tied")
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                Text(game.leaders.map(\.name).joined(separator: " & "))
                    .font(.headline).foregroundStyle(QTheme.ink)
                    .contentTransition(.interpolate)
            }
            Spacer()
            if let leadingTotal {
                Text("\(leadingTotal)")
                    .font(.title2.monospacedDigit().bold())
                    .contentTransition(.numericText(value: Double(leadingTotal)))
            }
        }
        .qCard()
        .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? "" : leaderKey) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                SpringKeyframe(1.04, duration: 0.18, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
        }
    }
}

private enum GameFeedback {
    case roundSaved
    case roundUpdated
    case roundChanged
    case leaderChanged

    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .roundSaved: .impact(weight: .medium)
        case .roundUpdated: .success
        case .roundChanged: .selection
        case .leaderChanged: .impact(weight: .heavy)
        }
    }
}

private struct BonusBadge: View {
    let bonus: RoundBonus

    var body: some View {
        Label("\(bonus.shortTitle) +\(RoundBonus.points)", systemImage: bonus.systemImage)
            .font(.caption2.bold())
            .foregroundStyle(QTheme.gold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(QTheme.gold.opacity(0.16), in: Capsule())
    }
}

private struct ScoreInputField: View {
    @Binding var scores: [UUID: String]
    @Binding var bonuses: RoundBonuses
    let playerID: UUID
    let players: [Player]
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
                .contentTransition(.numericText())
                .animation(QMotion.snappy, value: text)
                .frame(width: 90, alignment: .trailing)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(QTheme.cream, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(QTheme.sage, lineWidth: isShowingKeypad ? 2 : 0)
                }
                .animation(QMotion.snappy, value: isShowingKeypad)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isShowingKeypad) { _, isShowing in isShowing }
        .accessibilityLabel("Score")
        .accessibilityValue(text.isEmpty ? "Not entered" : text)
        .accessibilityHint("Opens the score keypad")
        .popover(isPresented: $isShowingKeypad, attachmentAnchor: .rect(.bounds)) {
            ScoreKeypad(scores: $scores, bonuses: $bonuses, playerID: playerID, players: players)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct ScoreKeypad: View {
    @Binding var scores: [UUID: String]
    @Binding var bonuses: RoundBonuses
    let playerID: UUID
    let players: [Player]
    @State private var keyTick = 0
    @State private var bonusTick = 0

    private var text: String {
        get { scores[playerID, default: ""] }
        nonmutating set { scores[playerID] = newValue }
    }

    private let rows = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(RoundBonus.allCases) { bonus in
                    bonusChip(bonus)
                }
            }

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
                keypadButton("+/−", action: toggleSign)
                    .accessibilityLabel("Make score negative or positive")

                keypadButton("0") {
                    appendDigit(0)
                }

                keypadButton(systemImage: "delete.left") {
                    guard !text.isEmpty else { return }
                    text.removeLast()
                    keyTick += 1
                }
                .accessibilityLabel("Delete")
            }
        }
        .frame(width: 154, alignment: .center)
        .padding(10)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: keyTick)
        .sensoryFeedback(.impact(weight: .medium), trigger: bonusTick)
    }

    /// Small tappable label at the top of the keypad. Highlighted when this
    /// player has the bonus; tapping it takes it from whoever had it.
    private func bonusChip(_ bonus: RoundBonus) -> some View {
        let isMine = bonuses[bonus] == playerID

        return Button {
            withAnimation(QMotion.snappy) {
                bonuses.toggle(bonus, for: playerID)
            }
            bonusTick += 1
        } label: {
            Text(bonus.title)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isMine ? Color.white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isMine ? QTheme.gold : QTheme.paper, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bonus.title), plus \(RoundBonus.points)")
        .accessibilityAddTraits(isMine ? .isSelected : [])
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
        keyTick += 1
    }

    private func toggleSign() {
        if text.hasPrefix("-") {
            text.removeFirst()
        } else {
            text = "-" + text
        }
        keyTick += 1
    }

}

struct StandingsView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(game.rankedPlayers) { player in
                let rank = game.rank(of: player.id)
                HStack {
                    Text("\(rank)").font(.headline.monospacedDigit()).foregroundStyle(rank == 1 ? QTheme.gold : .secondary).frame(width: 28)
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

enum CelebrationStyle {
    /// The game was just won on this screen.
    case full
    /// A finished game reopened later: the same show, sped up.
    case quick
}

struct CompletedGameView: View {
    let game: Game
    var celebration: CelebrationStyle = .quick
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var trophyBounce = 0
    @State private var hapticBeat = 0

    private var isTie: Bool { game.leaders.count > 1 }
    /// How much faster the reopen version runs.
    private var rate: Double { celebration == .full ? 1 : 2.2 }

    private var confettiStyle: ConfettiStyle? {
        switch (celebration, isTie) {
        case (.full, false): .full
        case (.full, true): .gentle
        case (.quick, false): .quick
        case (.quick, true): nil
        }
    }

    var body: some View {
        let ranked = game.rankedPlayers

        ScrollView {
            VStack(spacing: 22) {
                Image(systemName: isTie ? "medal.fill" : "trophy.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(QTheme.gold)
                    .symbolEffect(.bounce, value: trophyBounce)
                    .shadow(color: QTheme.gold.opacity(revealed ? 0.45 : 0), radius: 18)
                    .scaleEffect(revealed ? 1 : 0.3)
                    .rotationEffect(.degrees(revealed || reduceMotion ? 0 : -20))
                    .opacity(revealed ? 1 : 0)
                    .animation(entrance(delay: 0), value: revealed)
                    .padding(.top, 18)

                Text(winnerTitle)
                    .font(.largeTitle.bold()).foregroundStyle(QTheme.ink)
                    .multilineTextAlignment(.center)
                    .scaleEffect(revealed || reduceMotion ? 1 : 0.6)
                    .opacity(revealed ? 1 : 0)
                    .animation(entrance(delay: 0.15), value: revealed)

                Text(game.mode.title + " • " + game.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
                    .opacity(revealed ? 1 : 0)
                    .animation(entrance(delay: 0.25), value: revealed)

                VStack(spacing: 0) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, player in
                        let rank = game.rank(of: player.id)
                        HStack {
                            Group {
                                if rank == 1 {
                                    Image(systemName: "crown.fill").foregroundStyle(QTheme.gold)
                                } else {
                                    Text("\(rank)").foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 28)
                            Text(player.name).font(.headline)
                            Spacer()
                            Text("\(game.total(for: player.id))").font(.title3.monospacedDigit().bold())
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            rank == 1 ? QTheme.gold.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .opacity(revealed ? 1 : 0)
                        .offset(x: revealed || reduceMotion ? 0 : 40)
                        .animation(entrance(delay: 0.35 + Double(index) * 0.09), value: revealed)
                        if player.id != ranked.last?.id { Divider() }
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
                                        roundCell(player: player, round: round)
                                    }
                                }
                            }
                        }
                    }
                    if game.bonuses?.values.contains(where: { !$0.isEmpty }) == true {
                        Label("Includes Longest Word and Most Words bonuses", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .qCard()
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed || reduceMotion ? 0 : 24)
                .animation(entrance(delay: 0.45 + Double(ranked.count) * 0.09), value: revealed)
            }
            .padding()
        }
        .overlay {
            if !reduceMotion, let confettiStyle {
                ConfettiView(style: confettiStyle)
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(trigger: hapticBeat) { _, beat in
            celebrationFeedback(beat: beat)
        }
        .task { await celebrate() }
    }

    @ViewBuilder
    private func roundCell(player: Player, round: Int) -> some View {
        let bonus = game.bonusPoints(for: player.id, roundIndex: round)
        HStack(spacing: 2) {
            Text("\(game.score(for: player.id, roundIndex: round) ?? 0)").monospacedDigit()
            if bonus > 0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(QTheme.gold)
                    .accessibilityLabel("includes \(bonus) bonus points")
            }
        }
    }

    private func celebrationFeedback(beat: Int) -> SensoryFeedback? {
        guard beat > 0 else { return nil }
        guard celebration == .full else { return SensoryFeedback.impact(weight: .light) }
        if beat == 1 {
            return isTie ? SensoryFeedback.impact(weight: .medium) : SensoryFeedback.success
        }
        return SensoryFeedback.impact(weight: .light, intensity: 0.8)
    }

    private func entrance(delay: Double) -> Animation {
        if reduceMotion {
            return .easeOut(duration: 0.25)
        }
        return QMotion.bouncy.speed(rate).delay(delay / rate)
    }

    private func celebrate() async {
        guard !revealed else { return }
        revealed = true
        hapticBeat = 1
        guard !reduceMotion else { return }

        try? await Task.sleep(for: .seconds(0.45 / rate))
        trophyBounce += 1
        guard celebration == .full, !isTie else { return }

        // A short drumroll of taps as the standings slide in.
        for _ in 0..<2 {
            try? await Task.sleep(for: .seconds(0.12))
            hapticBeat += 1
        }
    }

    private var winnerTitle: String {
        guard let firstLeader = game.leaders.first else { return "Game Complete" }
        return game.leaders.count == 1 ? "\(firstLeader.name) Wins!" : "It’s a Tie!"
    }
}
