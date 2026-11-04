//
//  ContentView.swift
//  qScore
//
//  Created by Adam Moore on 9/22/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            Tab("Games", systemImage: "rectangle.stack.fill", value: AppTab.games) {
                NavigationStack(path: $store.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            switch route {
                            case .setup:
                                GameSetupView()
                            case .game(let id):
                                if let game = store.game(withID: id) {
                                    GameView(gameID: game.id)
                                } else {
                                    ContentUnavailableView(
                                        "Game Not Found",
                                        systemImage: "questionmark.folder",
                                        description: Text("This game is no longer available.")
                                    )
                                }
                            case .history:
                                HistoryView()
                            }
                        }
                }
            }

            Tab("Dictionary", systemImage: "text.book.closed.fill", value: AppTab.dictionary) {
                NavigationStack {
                    DictionaryLookupView()
                }
            }
        }
        .tint(QTheme.ink)
    }
}

#Preview {
    ContentView()
        .environment(GameStore.preview)
}
