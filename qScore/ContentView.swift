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
            TopDropPanel(
                isPresented: store.isShowingRules,
                heightFraction: 0.74,
                accessibilityCloseLabel: "Close rules",
                onClose: { store.isShowingRules = false }
            ) {
                QuiddlerRulesView { store.isShowingRules = false }
            }
        }
        .overlay {
            TopDropPanel(
                isPresented: store.standingsGameID != nil,
                accessibilityCloseLabel: "Close standings",
                onClose: { store.standingsGameID = nil }
            ) {
                if let game = store.standingsGameID.flatMap({ store.game(withID: $0) }) {
                    StandingsView(game: game) { store.standingsGameID = nil }
                }
            }
        }
    }
}

/// A panel that drops down from the top of the screen and dims everything,
/// including the tab bar. Used for the rules and the standings, whose
/// buttons live at the top. Tap the dimmed area, press Done, or drag the
/// grabber up to close it.
private struct TopDropPanel<Content: View>: View {
    let isPresented: Bool
    /// Share of the screen height to fill, or nil to fit the content.
    var heightFraction: CGFloat? = nil
    let accessibilityCloseLabel: String
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let screenHeight = proxy.size.height + topInset
            let panelHeight = heightFraction.map { screenHeight * $0 - topInset }

            ZStack(alignment: .top) {
                if isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture(perform: onClose)
                        .transition(.opacity)
                        .accessibilityLabel(accessibilityCloseLabel)
                        .accessibilityAddTraits(.isButton)

                    sized(content(), panelHeight: panelHeight)
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
                                : AnyTransition.offset(y: -((panelHeight ?? screenHeight) + topInset + 40))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .allowsHitTesting(isPresented)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : QMotion.smooth, value: isPresented)
        .sensoryFeedback(.impact(weight: .light), trigger: isPresented)
    }

    /// Fixed height when a fraction is given; otherwise just as tall as the content.
    @ViewBuilder
    private func sized(_ view: Content, panelHeight: CGFloat?) -> some View {
        if let panelHeight {
            view.frame(height: panelHeight)
        } else {
            view
                .padding(.bottom, 30)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                            onClose()
                        }
                        withAnimation(QMotion.snappy) { dragOffset = 0 }
                    }
            )
            .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
        .environment(GameStore.preview)
}
