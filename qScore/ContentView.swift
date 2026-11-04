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
        .sensoryFeedback(.selection, trigger: store.selectedTab)
        .overlay {
            RulesPanelOverlay(isPresented: $store.isShowingRules)
        }
    }
}

/// The rules drop down from the top of the screen and dim everything,
/// including the tab bar. Tap the dimmed area, press Done, or drag the
/// panel up to close it.
private struct RulesPanelOverlay: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let panelHeight = (proxy.size.height + topInset) * 0.74 - topInset

            ZStack(alignment: .top) {
                if isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture(perform: close)
                        .transition(.opacity)
                        .accessibilityLabel("Close rules")
                        .accessibilityAddTraits(.isButton)

                    QuiddlerRulesView(onDone: close)
                        .frame(height: panelHeight)
                        .background(alignment: .top) {
                            UnevenRoundedRectangle(
                                bottomLeadingRadius: 30,
                                bottomTrailingRadius: 30,
                                style: .continuous
                            )
                            .fill(QTheme.cream)
                            .overlay {
                                UnevenRoundedRectangle(
                                    bottomLeadingRadius: 30,
                                    bottomTrailingRadius: 30,
                                    style: .continuous
                                )
                                .fill(
                                    LinearGradient(
                                        colors: [QTheme.sage.opacity(0.14), QTheme.sage.opacity(0.04)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }
                            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
                            .ignoresSafeArea(edges: .top)
                        }
                        .overlay(alignment: .bottom) {
                            grabber
                        }
                        .offset(y: min(0, dragOffset))
                        .transition(
                            reduceMotion
                                ? AnyTransition.opacity
                                : AnyTransition.offset(y: -(panelHeight + topInset + 40))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(isPresented)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : QMotion.smooth, value: isPresented)
        .sensoryFeedback(.impact(weight: .light), trigger: isPresented)
    }

    private var grabber: some View {
        Capsule()
            .fill(QTheme.ink.opacity(0.22))
            .frame(width: 40, height: 5)
            .padding(.vertical, 10)
            .padding(.horizontal, 60)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height < -60 || value.predictedEndTranslation.height < -140 {
                            close()
                        }
                        withAnimation(QMotion.snappy) { dragOffset = 0 }
                    }
            )
            .accessibilityHidden(true)
    }

    private func close() {
        isPresented = false
    }
}

#Preview {
    ContentView()
        .environment(GameStore.preview)
}
