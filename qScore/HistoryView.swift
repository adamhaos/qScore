import SwiftUI

struct HistoryView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ZStack {
            QBackground()
            if store.completedGames.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Finish a game to see it here."))
            } else {
                List {
                    ForEach(store.completedGames) { game in
                        NavigationLink(value: AppRoute.game(game.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary(for: game)).font(.headline)
                                Text("\(game.mode.title) • \(game.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                        .contextMenu {
                            Button("Delete Game", systemImage: "trash", role: .destructive) {
                                withAnimation(QMotion.smooth) {
                                    store.deleteGame(withID: game.id)
                                }
                            }
                        }
                    }
                    .onDelete { store.deleteGames(at: $0, from: store.completedGames) }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .animation(QMotion.smooth, value: store.completedGames.isEmpty)
        .sensoryFeedback(trigger: store.completedGames.count) { oldCount, newCount in
            newCount < oldCount ? SensoryFeedback.impact(weight: .medium) : nil
        }
        .navigationTitle("Game History")
    }

    private func summary(for game: Game) -> String {
        guard let firstLeader = game.leaders.first else { return "Game complete" }
        return game.leaders.count == 1
            ? "\(firstLeader.name) Won with \(game.total(for: firstLeader.id))"
            : "Tie Game"
    }
}
