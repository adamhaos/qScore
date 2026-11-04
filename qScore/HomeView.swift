import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var showingSetup = false
    @State private var gameToOpen: UUID?

    var body: some View {
        ZStack {
            QBackground()
            GeometryReader { _ in
                VStack(spacing: 28) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !store.activeGames.isEmpty {
                                sectionTitle("Continue Playing", systemImage: "play.fill")
                                ScrollView {
                                    LazyVStack(spacing: 12) {
                                        ForEach(store.activeGames) { game in
                                            Button { store.path.append(.game(game.id)) } label: {
                                                GameSummaryCard(game: game, showsShadow: false)
                                                    .contextMenu {
                                                        Button(
                                                            "Delete Game",
                                                            systemImage: "trash",
                                                            role: .destructive
                                                        ) {
                                                            withAnimation(QMotion.smooth) {
                                                                store.deleteGame(withID: game.id)
                                                            }
                                                        }
                                                    }
                                            }
                                            .buttonStyle(.pressable(scale: 0.97))
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .move(edge: .top)),
                                                removal: .opacity.combined(with: .scale(scale: 0.9))
                                            ))
                                        }
                                    }
                                    .padding(.vertical, 12)
                                }
                                .frame(height: continuePlayingHeight)
                                .scrollIndicators(.visible)
                            }

                            HStack {
                                sectionTitle("Recent Games", systemImage: "clock.arrow.circlepath")
                                Spacer()
                                if !store.completedGames.isEmpty {
                                    Button("See All") { store.path.append(.history) }
                                        .font(.subheadline.weight(.semibold))
                                }
                            }

                            if store.completedGames.isEmpty {
                                ContentUnavailableView(
                                    "No Finished Games",
                                    systemImage: "rectangle.stack",
                                    description: Text("Completed games will appear here.")
                                )
                                .frame(maxWidth: .infinity)
                                .qCard()
                            } else {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)
                                    ],
                                    spacing: 12
                                ) {
                                    ForEach(store.completedGames.prefix(4)) { game in
                                        Button { store.path.append(.game(game.id)) } label: {
                                            RecentGameGridCard(game: game)
                                        }
                                        .buttonStyle(.pressable(scale: 0.96))
                                        .contextMenu {
                                            Button("Delete Game", systemImage: "trash", role: .destructive) {
                                                withAnimation(QMotion.smooth) {
                                                    store.deleteGame(withID: game.id)
                                                }
                                            }
                                        }
                                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                    }
                                }
                            }

                        }
                        .padding(.vertical, 4)
                        .padding(.bottom, 44)
                        .animation(QMotion.smooth, value: store.activeGames.map(\.id))
                        .animation(QMotion.smooth, value: store.completedGames.map(\.id))
                    }
                    .layoutPriority(1)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.88),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("qScore")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(QTheme.ink)
                            Text("A Calmer Way to Keep Score.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showingSetup = true
                        } label: {
                            Label("Start a New Game", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(QTheme.sage)
                        .overlay {
                            MovingGreenBorder()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 52)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.isShowingRules = true
                } label: {
                    Label("Quiddler Rules", systemImage: "book.pages")
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showingSetup) { _, isShowing in isShowing }
        .sensoryFeedback(trigger: store.games.count) { oldCount, newCount in
            newCount < oldCount ? SensoryFeedback.impact(weight: .medium) : nil
        }
        .sheet(isPresented: $showingSetup, onDismiss: openCreatedGame) {
            GameSetupView { gameID in
                gameToOpen = gameID
                showingSetup = false
            }
            .presentationDragIndicator(.visible)
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage).font(.title3.bold()).foregroundStyle(QTheme.ink)
    }

    private var continuePlayingHeight: CGFloat {
        store.activeGames.count == 1 ? 108 : 204
    }

    private func openCreatedGame() {
        guard let gameToOpen else { return }
        self.gameToOpen = nil
        store.path.append(.game(gameToOpen))
    }

}

private struct RecentGameGridCard: View {
    let game: Game

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "trophy.fill")
                .font(.caption.bold())
                .foregroundStyle(QTheme.gold)
                .frame(width: 30, height: 30)
                .background(QTheme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(resultText)
                    .font(.caption.bold())
                    .foregroundStyle(QTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("\(game.players.count) players")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(.tertiary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qCard()
    }

    private var resultText: String {
        let names = game.leaders.map(\.name)
        guard let firstName = names.first else { return "Game Complete" }
        return names.count == 1 ? "\(firstName) Won" : "Tie Game"
    }
}

private struct MovingGreenBorder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let rotation = reduceMotion ? 0 : elapsed.truncatingRemainder(dividingBy: 2.4) / 2.4 * 360

            Capsule()
                .stroke(
                    AngularGradient(
                        colors: [
                            QTheme.sage.opacity(0.12),
                            QTheme.sage.opacity(0.35),
                            QTheme.sage,
                            Color.white.opacity(0.9),
                            QTheme.sage,
                            QTheme.sage.opacity(0.12)
                        ],
                        center: .center,
                        angle: .degrees(rotation)
                    ),
                    lineWidth: 3
                )
                .shadow(color: QTheme.sage.opacity(0.5), radius: 5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct GameSummaryCard: View {
    let game: Game
    var showsShadow = true

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(game.isComplete ? QTheme.gold.opacity(0.18) : QTheme.sage.opacity(0.16))
                Image(systemName: game.isComplete ? "trophy.fill" : "rectangle.stack.fill")
                    .foregroundStyle(game.isComplete ? QTheme.gold : QTheme.sage)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(game.isComplete ? winnerText : "Round \(game.roundNumber) of \(game.mode.rounds.count)")
                    .font(.headline).foregroundStyle(QTheme.ink)
                Text("\(game.players.map(\.name).joined(separator: ", ")) • \(game.mode.title)")
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .qCard(showsShadow: showsShadow)
    }

    private var winnerText: String {
        let names = game.leaders.map(\.name)
        guard let firstName = names.first else { return "Game Complete" }
        return names.count == 1 ? "\(firstName) Won" : "Tie Game"
    }
}
