import SwiftUI
import Observation

@MainActor
@Observable
private final class PlayerEntry: Identifiable {
    let id = UUID()
    var name = ""
}

struct GameSetupView: View {
    @Environment(GameStore.self) private var store
    let onStart: ((UUID) -> Void)?
    @State private var mode: GameMode = .standard
    @State private var playerNames = [PlayerEntry(), PlayerEntry()]
    @FocusState private var focusedPlayer: UUID?

    init(onStart: ((UUID) -> Void)? = nil) {
        self.onStart = onStart
    }

    var body: some View {
        ZStack {
            QBackground()
            LinearGradient(
                colors: [
                    QTheme.sage.opacity(0.24),
                    QTheme.sage.opacity(0.10),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a game")
                            .font(.title2.bold())

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                            spacing: 10
                        ) {
                            ForEach([GameMode.reverse, .standard, .upAndBack]) { option in
                                GameModeTile(
                                    mode: option,
                                    isSelected: mode == option
                                ) {
                                    mode = option
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Who’s playing?").font(.title2.bold())
                        Text("Add 2–8 players. You can use names or initials.").foregroundStyle(.secondary)
                        VStack(spacing: 10) {
                            ForEach(playerNames) { player in
                                @Bindable var player = player

                                HStack {
                                    Image(systemName: "person.fill").foregroundStyle(QTheme.sage)
                                    TextField("Player \(playerNumber(for: player.id))", text: $player.name)
                                        .textInputAutocapitalization(.words)
                                        .focused($focusedPlayer, equals: player.id)
                                    if playerNames.count > 2 {
                                        Button(role: .destructive) {
                                            if focusedPlayer == player.id {
                                                focusedPlayer = nil
                                            }
                                            playerNames.removeAll { $0.id == player.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                        }
                                    }
                                }
                                .padding(12)
                                .background(QTheme.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                            }
                            if playerNames.count < 8 {
                                Button {
                                    let player = PlayerEntry()
                                    playerNames.append(player)
                                    focusedPlayer = player.id
                                } label: {
                                    Label("Add Player", systemImage: "plus").frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .qCard()
                    }

                    Button {
                        let id = store.createGame(mode: mode, playerNames: resolvedNames)
                        if let onStart {
                            onStart(id)
                        } else {
                            if !store.path.isEmpty {
                                store.path.removeLast()
                            }
                            store.path.append(.game(id))
                        }
                    } label: {
                        Text("Start Game")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(QTheme.sage)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.inline)
        .presentationDetents(sheetDetents)
    }

    private var sheetDetents: Set<PresentationDetent> {
        if playerNames.count >= 6 {
            return [.large]
        }

        let additionalPlayers = playerNames.count - 2
        return [.fraction(0.68 + Double(additionalPlayers) * 0.07)]
    }

    private var resolvedNames: [String] {
        playerNames.enumerated().map { index, player in
            let trimmed = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Player \(index + 1)" : trimmed
        }
    }

    private func playerNumber(for id: UUID) -> Int {
        guard let index = playerNames.firstIndex(where: { $0.id == id }) else { return 1 }
        return index + 1
    }
}

private struct GameModeTile: View {
    let mode: GameMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(mode.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 2)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? QTheme.sage : .secondary)
                }

                Text(mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .padding(12)
            .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? QTheme.sage : QTheme.ink.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
