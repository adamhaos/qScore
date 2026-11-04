import Foundation
import SafariServices
import SwiftUI

struct DictionaryLookupView: View {
    @State private var word = ""
    @AppStorage("dictionaryLookupHistory") private var lookupHistoryData = Data()
    @State private var entry: DictionaryEntry?
    @State private var lookupHistory: [DictionaryEntry] = []
    @State private var hasLoadedHistory = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var leftDictionaryAt: Date?
    @State private var scrollResetID = UUID()
    @State private var lookupTask: Task<Void, Never>?
    @State private var lookupID = UUID()

    var body: some View {
        ZStack {
            QBackground()

            ScrollView {
                VStack(spacing: 20) {
                    DictionaryHero()
                    DictionarySearchBar(
                        word: $word,
                        isSearchDisabled: cleanWord.isEmpty || isLoading,
                        onSearch: submitLookup
                    )

                    Group {
                        if isLoading {
                            DictionaryLoadingView()
                        } else if let entry {
                            DictionaryEntryView(entry: entry)
                                .id(entry.id)
                        } else if let errorMessage {
                            DictionaryErrorView(message: errorMessage)
                        } else {
                            DictionaryPromptView()
                        }
                    }
                    .transition(.blurReplace)

                    if !lookupHistory.isEmpty {
                        DictionaryHistoryView(
                            entries: Array(lookupHistory.prefix(4)),
                            onSelect: selectHistoryEntry
                        )
                    }
                }
                .padding()
                .animation(QMotion.smooth, value: resultState)
                .animation(QMotion.smooth, value: lookupHistory.map(\.id))
                .sensoryFeedback(trigger: entry?.id) { _, newID in
                    guard newID != nil, let entry else { return nil }
                    switch entry.resolvedLegality {
                    case .legal: return SensoryFeedback.success
                    case .illegal: return SensoryFeedback.error
                    case .unverified, .meaningDependent: return SensoryFeedback.warning
                    }
                }
            }
            .id(scrollResetID)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await QuiddlerWordList.preload()
            loadHistoryIfNeeded()
        }
        .onAppear {
            resetAfterExtendedAbsenceIfNeeded()
        }
        .onDisappear {
            lookupTask?.cancel()
            lookupID = UUID()
            isLoading = false
            leftDictionaryAt = .now
        }
    }

    /// Changes whenever the main result card swaps, so the swap animates.
    private var resultState: String {
        if isLoading { return "loading" }
        if let entry { return "entry:" + entry.id }
        if errorMessage != nil { return "error" }
        return "prompt"
    }

    private var cleanWord: String {
        word.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitLookup() {
        lookupTask?.cancel()
        let requestID = UUID()
        lookupID = requestID
        let submittedWord = cleanWord
        lookupTask = Task {
            await lookUp(submittedWord: submittedWord, requestID: requestID)
        }
    }

    @MainActor
    private func lookUp(submittedWord: String, requestID: UUID) async {
        guard !Task.isCancelled, lookupID == requestID else { return }
        guard !submittedWord.isEmpty else { return }

        if case .illegal(let reason) = QuiddlerWordValidator.fallbackCheck(submittedWord) {
            entry = DictionaryEntry(word: submittedWord, meanings: [], legality: .illegal(reason))
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        entry = nil
        errorMessage = nil

        // Lookups are offline, so the only thing that can stop one is a newer lookup.
        guard let newEntry = try? await QuiddlerWordValidator.lookup(submittedWord),
              !Task.isCancelled, lookupID == requestID else { return }

        entry = newEntry
        recordLookup(newEntry)
        isLoading = false
    }

    private func selectHistoryEntry(_ selectedEntry: DictionaryEntry) {
        word = selectedEntry.word
        submitLookup()
    }

    private func recordLookup(_ lookedUpEntry: DictionaryEntry) {
        lookupHistory.removeAll {
            $0.word.caseInsensitiveCompare(lookedUpEntry.word) == .orderedSame
        }
        lookupHistory.insert(lookedUpEntry, at: 0)
        lookupHistory = Array(lookupHistory.prefix(15))
        lookupHistoryData = (try? JSONEncoder().encode(lookupHistory)) ?? Data()
    }

    private func loadHistoryIfNeeded() {
        guard !hasLoadedHistory else { return }
        hasLoadedHistory = true

        guard let savedHistory = try? JSONDecoder().decode(
            [DictionaryEntry].self,
            from: lookupHistoryData
        ) else { return }

        // Check saved words again so they follow the current word lists
        // (and drop the web definitions older versions saved).
        lookupHistory = savedHistory.map { QuiddlerWordValidator.entry(for: $0.word) }
    }

    private func resetAfterExtendedAbsenceIfNeeded() {
        guard let leftDictionaryAt,
              Date.now.timeIntervalSince(leftDictionaryAt) >= 5 else { return }

        word = ""
        entry = nil
        errorMessage = nil
        isLoading = false
        scrollResetID = UUID()
        self.leftDictionaryAt = nil
    }
}

private struct DictionaryHero: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.book.closed.fill")
                .font(.title2)
                .foregroundStyle(QTheme.sage)
                .frame(width: 46, height: 46)
                .background(QTheme.sage.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Word Check")
                    .font(.title2.bold())
                    .foregroundStyle(QTheme.ink)

                Text("Quick definitions. No distractions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct DictionarySearchBar: View {
    @Binding var word: String
    let isSearchDisabled: Bool
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(QTheme.sage)

            TextField("Type a word", text: $word)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title3)
                .submitLabel(.search)
                .onSubmit(onSearch)

            Button("Look Up", action: onSearch)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(QTheme.sage)
                .disabled(isSearchDisabled)
        }
        .padding(12)
        .background(QTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(QTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: QTheme.ink.opacity(0.06), radius: 10, y: 4)
    }
}

private struct DictionaryHistoryView: View {
    let entries: [DictionaryEntry]
    let onSelect: (DictionaryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Lookups", systemImage: "clock.arrow.circlepath")
                .font(.title3.bold())
                .foregroundStyle(QTheme.ink)

            ForEach(entries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    DictionaryHistoryCard(entry: entry)
                }
                .buttonStyle(.pressable(scale: 0.97))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DictionaryHistoryCard: View {
    let entry: DictionaryEntry

    private var statusColor: Color {
        switch entry.resolvedLegality {
        case .legal: QTheme.sage
        case .illegal: .red
        case .unverified, .meaningDependent: QTheme.gold
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(statusColor.opacity(0.14))

                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(statusColor)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.word)
                    .font(.headline)
                    .foregroundStyle(QTheme.ink)

                Text(entry.definitionPreview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .qCard()
    }
}

private struct DictionaryEntryView: View {
    let entry: DictionaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DictionaryLegalityView(legality: entry.resolvedLegality)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.word)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(QTheme.ink)

                if let phonetic = entry.displayPhonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundStyle(QTheme.sage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DictionarySourceButtons(word: entry.word)

            if entry.resolvedLegality.isLegal,
               ["qu", "in", "er", "cl", "th"].contains(entry.word.lowercased()) {
                Text("Use two separate letter cards, not a single double-letter card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if entry.definitionSource == QuiddlerWordList.sourceName {
                Text("Rules check: ENABLE word list + modern words")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

private struct DictionaryLegalityView: View {
    let legality: QuiddlerWordLegality

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(legality.title)
                    .font(.headline)

                if let explanation = legality.explanation {
                    Text(explanation)
                        .font(.subheadline)
                }
            }
        } icon: {
            Image(systemName: legality.systemImage)
                .font(.title2)
        }
        .foregroundStyle(statusColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            statusColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var statusColor: Color {
        switch legality {
        case .legal: QTheme.sage
        case .illegal: .red
        case .unverified: QTheme.gold
        case .meaningDependent: QTheme.gold
        }
    }
}

/// Ways to read a word's meaning: the iPhone's own dictionary, which works
/// offline, and Dictionary.com, which the family uses to settle challenges.
/// Both open in a sheet so the game stays a swipe away.
private struct DictionarySourceButtons: View {
    let word: String
    /// Nil until checked. The iPhone dictionary is only offered when it has
    /// an entry, since otherwise it shows an empty "No Content Found" page.
    @State private var hasSystemDefinition: Bool?
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable {
        case system, web
        var id: Self { self }
    }

    private var dictionaryURL: URL? {
        guard let encoded = word.lowercased().addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://www.dictionary.com/browse/" + encoded)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { buttons }
            VStack(spacing: 10) { buttons }
        }
        .task(id: word) {
            hasSystemDefinition = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .system:
                SystemDictionaryView(term: word)
                    .ignoresSafeArea()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .web:
                if let dictionaryURL {
                    SafariView(url: dictionaryURL)
                        .ignoresSafeArea()
                }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if hasSystemDefinition == true {
            Button {
                sheet = .system
            } label: {
                Label("Definition", systemImage: "character.book.closed.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(QTheme.sage)
            .accessibilityHint("Shows the iPhone dictionary entry")
        }

        if dictionaryURL != nil {
            // The main button when there's no iPhone definition to show.
            if hasSystemDefinition == true {
                dictionaryButton.buttonStyle(.bordered)
            } else {
                dictionaryButton.buttonStyle(.borderedProminent)
            }
        }
    }

    private var dictionaryButton: some View {
        Button {
            sheet = .web
        } label: {
            Label("Dictionary.com", systemImage: "safari")
                .frame(maxWidth: .infinity)
        }
        .tint(QTheme.sage)
        .accessibilityHint("Opens this word on Dictionary.com")
    }
}

/// The definition screen iOS shows for Look Up, from dictionaries on the device.
private struct SystemDictionaryView: UIViewControllerRepresentable {
    let term: String

    func makeUIViewController(context: Context) -> UIReferenceLibraryViewController {
        UIReferenceLibraryViewController(term: term)
    }

    func updateUIViewController(_ controller: UIReferenceLibraryViewController, context: Context) {}
}

/// Dictionary.com in an in-app browser, tinted to match the app.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(QTheme.sage)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

private struct DictionaryLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(QTheme.sage)
            Text("Finding that word…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .qCard()
    }
}

private struct DictionaryPromptView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 32))
                .foregroundStyle(QTheme.gold)
            Text("Settle the next word challenge")
                .font(.headline)
                .foregroundStyle(QTheme.ink)
            Text("Enter a word above to see if it can be played.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .qCard()
    }
}

private struct DictionaryErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "No Definition Found",
            systemImage: "questionmark.book.closed",
            description: Text(message)
        )
        .frame(maxWidth: .infinity)
        .qCard()
    }
}
