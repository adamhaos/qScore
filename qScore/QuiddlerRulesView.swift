import SwiftUI

struct QuiddlerRulesView: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: (() -> Void)?
    @State private var selectedPage = 1

    init(onDone: (() -> Void)? = nil) {
        self.onDone = onDone
    }

    var body: some View {
        ZStack {
            QTheme.cream
                .ignoresSafeArea()

            VStack(spacing: 10) {
                QuiddlerRulesHeader(onDone: close)

                TabView(selection: $selectedPage) {
                    QuiddlerScoringPage().tag(0)
                    QuiddlerBasicsPage().tag(1)
                    QuiddlerWordsPage().tag(2)
                    QuiddlerGoingOutPage().tag(3)
                    QuiddlerScoringPage().tag(4)
                    QuiddlerBasicsPage().tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedPage) {
                    if selectedPage == 0 {
                        resetPage(to: 4)
                    } else if selectedPage == 5 {
                        resetPage(to: 1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 52)
        }
    }

    private func resetPage(to page: Int) {
        Task { @MainActor in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedPage = page
            }
        }
    }

    private func close() {
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }
}

private struct QuiddlerRulesHeader: View {
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.title2)
                .foregroundStyle(QTheme.sage)
                .frame(width: 48, height: 48)
                .background(QTheme.sage.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Quiddler Rules")
                    .font(.title2.bold())
                    .foregroundStyle(QTheme.ink)
                Text("Swipe between the four quick guides")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button("Done", action: onDone)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(QTheme.sage)
        }
    }
}

private struct QuiddlerBasicsPage: View {
    var body: some View {
        QuiddlerRulePage(
            title: "Start & Play",
            subtitle: "Build words and finish with the highest score.",
            systemImage: "play.fill"
        ) {
            QuiddlerRuleRow(
                number: "1",
                title: "Deal",
                detail: "Begin with 3 cards. Add one each round until the eighth round, when everyone has 10."
            )
            QuiddlerRuleRow(
                number: "2",
                title: "Draw",
                detail: "Take the top card from either the face-down draw pile or face-up discard pile."
            )
            QuiddlerRuleRow(
                number: "3",
                title: "Build",
                detail: "Arrange cards into words, but keep them in your hand until you go out."
            )
            QuiddlerRuleRow(
                number: "4",
                title: "Discard",
                detail: "End every turn by placing one card on the discard pile."
            )
        }
    }
}

private struct QuiddlerWordsPage: View {
    private let restrictions = [
        "Proper nouns",
        "Prefixes or suffixes by themselves",
        "Abbreviations",
        "Hyphenated words"
    ]

    var body: some View {
        QuiddlerRulePage(
            title: "Allowable Words",
            subtitle: "Choose the dictionary everyone will use before play.",
            systemImage: "textformat.abc"
        ) {
            Label("Every word must use at least two cards.", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(QTheme.sage)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(restrictions, id: \.self) { restriction in
                Label(restriction, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(
                "You may check the agreed dictionary when it isn’t your turn.",
                systemImage: "book.closed.fill"
            )
            .font(.body)
            .foregroundStyle(QTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct QuiddlerGoingOutPage: View {
    var body: some View {
        QuiddlerRulePage(
            title: "Going Out",
            subtitle: "Use your whole hand and leave one card to discard.",
            systemImage: "flag.checkered"
        ) {
            QuiddlerRuleRow(
                number: "1",
                title: "Draw normally",
                detail: "Start your turn by taking a card from either pile."
            )
            QuiddlerRuleRow(
                number: "2",
                title: "Lay down your words",
                detail: "Every card except one must be part of an allowable word."
            )
            QuiddlerRuleRow(
                number: "3",
                title: "Discard the last card",
                detail: "This completes going out, even if the discarded card could have been played."
            )
            QuiddlerRuleRow(
                number: "4",
                title: "Final turns",
                detail: "Everyone else gets one more turn and lays down any words they can. Cards can’t be added to another player’s words."
            )
        }
    }
}

private struct QuiddlerScoringPage: View {
    var body: some View {
        QuiddlerRulePage(
            title: "Score & Challenge",
            subtitle: "Add words, subtract leftovers, then award bonuses.",
            systemImage: "plus.forwardslash.minus"
        ) {
            QuiddlerIconRule(
                systemImage: "plus.circle.fill",
                detail: "Add the printed value of cards used in allowable words."
            )
            QuiddlerIconRule(
                systemImage: "minus.circle.fill",
                detail: "Subtract unused cards. A round score cannot drop below zero."
            )
            QuiddlerIconRule(
                systemImage: "star.circle.fill",
                detail: "Add 10 for most words and 10 for the longest word by letters. Ties earn no bonus. With two players, choose only one bonus."
            )
            QuiddlerIconRule(
                systemImage: "exclamationmark.bubble.fill",
                detail: "Challenge immediately. The loser subtracts that word’s value, and the cards can’t be rearranged."
            )
        }
    }
}

private struct QuiddlerRulePage<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(QTheme.gold)
                    .frame(width: 36, height: 36)
                    .background(QTheme.gold.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(QTheme.ink)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 12)
    }
}

private struct QuiddlerRuleRow: View {
    let number: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.subheadline.bold())
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(QTheme.sage, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct QuiddlerIconRule: View {
    let systemImage: String
    let detail: LocalizedStringKey

    var body: some View {
        Label {
            Text(detail)
                .font(.body)
                .foregroundStyle(QTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(QTheme.gold)
        }
    }
}

#Preview {
    NavigationStack {
        QuiddlerRulesView()
    }
}
