import Foundation
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

                    if isLoading {
                        DictionaryLoadingView()
                    } else if let entry {
                        DictionaryEntryView(entry: entry)
                    } else if let errorMessage {
                        DictionaryErrorView(message: errorMessage)
                    } else {
                        DictionaryPromptView()
                    }

                    if !lookupHistory.isEmpty {
                        DictionaryHistoryView(
                            entries: Array(lookupHistory.prefix(4)),
                            onSelect: selectHistoryEntry
                        )
                    }
                }
                .padding()
            }
            .id(scrollResetID)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("Dictionary")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadHistoryIfNeeded()
            await QuiddlerWordList.preload()
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
        let normalizedWord = submittedWord.lowercased()
        guard !normalizedWord.isEmpty else { return }

        if case .illegal(let reason) = QuiddlerWordValidator.fallbackCheck(submittedWord) {
            entry = DictionaryEntry(word: submittedWord, meanings: [], legality: .illegal(reason))
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        entry = nil
        errorMessage = nil

        do {
            let newEntry = try await QuiddlerWordValidator.lookup(submittedWord)
            guard !Task.isCancelled, lookupID == requestID else { return }

            entry = newEntry
            recordLookup(newEntry)
        } catch let error as DictionaryLookupError {
            guard !Task.isCancelled, lookupID == requestID else { return }
            entry = DictionaryEntry(word: normalizedWord, meanings: [], legality: .unverified(error.localizedDescription))
        } catch {
            guard !Task.isCancelled, lookupID == requestID else { return }
            entry = DictionaryEntry(word: normalizedWord, meanings: [], legality: .unverified("The dictionary couldn't be reached. Check your connection and try again."))
        }

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

        lookupHistory = savedHistory.map { entry in
            entry.definitionSource == QuiddlerWordList.sourceName ? entry : DictionaryEntry(
                word: entry.word, meanings: [], legality: .unverified("Look up this word again to refresh its meaning.")
            )
        }
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
                .buttonStyle(.plain)
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

            ForEach(Array(entry.meanings.prefix(3))) { meaning in
                DictionaryMeaningView(meaning: meaning)
            }

            if entry.resolvedLegality.isLegal,
               ["qu", "in", "er", "cl", "th"].contains(entry.word.lowercased()) {
                Text("Use two separate letter cards, not a single double-letter card.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if entry.definitionSource == QuiddlerWordList.sourceName {
                Text(entry.meanings.isEmpty ? "Rules check: ENABLE word list" : "Rules check: ENABLE word list · Definitions: Wiktionary")
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

private struct DictionaryMeaningView: View {
    let meaning: DictionaryMeaning

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(meaning.partOfSpeech)
                .font(.headline)
                .foregroundStyle(QTheme.sage)
                .textCase(.uppercase)

            if let definition = meaning.definitions.first {
                DictionaryDefinitionRow(definition: definition)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .qCard()
    }
}

private struct DictionaryDefinitionRow: View {
    let definition: DictionaryDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(definition.definition)
                .font(.body)
                .foregroundStyle(QTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let example = definition.example {
                Text("“\(example)”")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
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
            Text("Enter a word above to see its definition.")
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

private struct DictionaryEntry: Codable, Identifiable {
    var id: String { word.lowercased() }
    let word: String
    let meanings: [DictionaryMeaning]
    let legality: QuiddlerWordLegality?
    var definitionSource: String?

    var displayPhonetic: String? { nil }

    var definitionPreview: String {
        meanings.first?.definitions.first?.definition ?? "Definition unavailable"
    }

    var resolvedLegality: QuiddlerWordLegality {
        legality ?? QuiddlerWordValidator.fallbackCheck(word)
    }

    init(
        word: String,
        meanings: [DictionaryMeaning],
        legality: QuiddlerWordLegality?,
        definitionSource: String? = nil
    ) {
        self.word = word
        self.meanings = meanings
        self.legality = legality
        self.definitionSource = definitionSource
    }

}

private enum QuiddlerWordLegality: Codable {
    case legal
    case illegal(String)
    case unverified(String)
    case meaningDependent(String)

    var isLegal: Bool {
        if case .legal = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .legal: "Legal Word"
        case .illegal: "Illegal Word"
        case .unverified: "Rules Check Unavailable"
        case .meaningDependent: "Check Meaning"
        }
    }

    var explanation: String? {
        switch self {
        case .legal: "Use at least two cards. Your agreed dictionary decides challenges."
        case .illegal(let reason), .unverified(let reason), .meaningDependent(let reason): reason
        }
    }

    var systemImage: String {
        switch self {
        case .legal: "checkmark.seal.fill"
        case .illegal: "xmark.octagon.fill"
        case .unverified: "questionmark.circle.fill"
        case .meaningDependent: "exclamationmark.circle.fill"
        }
    }
}

private enum QuiddlerWordValidator {
    private static let allowableHeadings = [
        "noun", "verb", "adjective", "adverb", "pronoun", "preposition",
        "conjunction", "interjection", "determiner", "article", "numeral"
    ]

    static func fallbackCheck(_ word: String) -> QuiddlerWordLegality {
        if word.count < 2 {
            return .illegal("Every word must use at least two cards.")
        }

        if word.contains(where: { $0 == "-" || $0 == "‐" || $0 == "‑" }) {
            return .illegal("Hyphenated words aren’t allowed.")
        }

        if word.contains(where: \.isWhitespace) {
            return .illegal("A play must be a single word.")
        }

        guard word.unicodeScalars.allSatisfy({
            (65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value))
        }) else {
            return .illegal("Use only letters A–Z. Punctuation and numbers can't be played.")
        }

        return .unverified("Check this word in your agreed dictionary.")
    }

    static func lookup(_ word: String) async throws -> DictionaryEntry {
        if case .illegal(let reason) = fallbackCheck(word) {
            return DictionaryEntry(word: word, meanings: [], legality: .illegal(reason))
        }
        let normalized = word.lowercased()

        await QuiddlerWordList.preload()
        guard QuiddlerWordList.isAvailable else {
            return DictionaryEntry(word: normalized, meanings: [], legality: .unverified("The word list is missing from this build. Check this word in your agreed dictionary."))
        }
        guard QuiddlerWordList.contains(normalized) else {
            return DictionaryEntry(
                word: normalized,
                meanings: [],
                legality: .illegal("Not in the Quiddler word list. Names, abbreviations, slang and foreign words aren't allowed."),
                definitionSource: QuiddlerWordList.sourceName
            )
        }

        // The word list alone decides legality. Wiktionary only supplies the
        // definitions shown, so being offline never changes the verdict.
        try Task.checkCancellation()
        let definitions = (try? await fetchDefinitions(for: normalized)) ?? []
        return DictionaryEntry(
            word: normalized,
            meanings: playableMeanings(from: definitions),
            legality: .legal,
            definitionSource: QuiddlerWordList.sourceName
        )
    }

    private static func fetchDefinitions(for word: String) async throws -> [WiktionaryMeaning] {
        let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition")!.appendingPathComponent(word)
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("qScore/1.0 (Quiddler word validation)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DictionaryLookupError.unavailable }
        if http.statusCode == 404 { throw DictionaryLookupError.wordNotFound }
        guard (200...299).contains(http.statusCode) else { throw DictionaryLookupError.unavailable }
        let entries = try JSONDecoder().decode([String: [WiktionaryMeaning]].self, from: data)
        return (entries["en"] ?? []).filter { $0.language == "English" }
    }

    /// Keeps the everyday senses of a word and drops abbreviation,
    /// proper-noun and misspelling senses so the definitions shown match
    /// the way the word can be played.
    private static func playableMeanings(from definitions: [WiktionaryMeaning]) -> [DictionaryMeaning] {
        definitions.compactMap { meaning -> DictionaryMeaning? in
            let partOfSpeech = meaning.partOfSpeech.lowercased()
            guard allowableHeadings.contains(partOfSpeech) else { return nil }
            let eligible = meaning.definitions.compactMap { sense -> DictionaryDefinition? in
                guard let text = DictionaryHTMLText.plainText(sense.definition), !text.isEmpty else { return nil }
                let abbreviation = #"(?i)\b(?:abbreviation|initialism|acronym|short) (?:of|for)\b"#
                if text.range(of: abbreviation, options: .regularExpression) != nil ||
                    text.localizedCaseInsensitiveContains("misspelling of") {
                    return nil
                }
                return DictionaryDefinition(partOfSpeech: partOfSpeech, definition: text)
            }
            return eligible.isEmpty ? nil : DictionaryMeaning(partOfSpeech: partOfSpeech, definitions: eligible)
        }
    }
}

private struct WiktionaryMeaning: Decodable {
    let partOfSpeech: String
    let language: String
    let definitions: [WiktionarySense]
}

private struct WiktionarySense: Decodable {
    let definition: String
}

private final class DictionaryHTMLText: NSObject, XMLParserDelegate {
    private var text = ""

    static func plainText(_ html: String) -> String? {
        let fragment = html
            .replacingOccurrences(of: #"<(?:link|br|hr|img|meta|input)\b[^>]*>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "&nbsp;", with: "&#160;")
            .replacingOccurrences(of: "&ndash;", with: "&#8211;")
            .replacingOccurrences(of: "&mdash;", with: "&#8212;")
        let parser = XMLParser(data: Data(("<root>" + fragment + "</root>").utf8))
        parser.shouldResolveExternalEntities = false
        let reader = DictionaryHTMLText()
        parser.delegate = reader
        guard parser.parse() else { return nil }
        return reader.text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }
}

private struct DictionaryMeaning: Codable, Identifiable {
    let id: UUID
    let partOfSpeech: String
    let definitions: [DictionaryDefinition]

    init(
        id: UUID = UUID(),
        partOfSpeech: String,
        definitions: [DictionaryDefinition]
    ) {
        self.id = id
        self.partOfSpeech = partOfSpeech
        self.definitions = definitions
    }
}

private struct DictionaryDefinition: Codable, Identifiable {
    let id: UUID
    let partOfSpeech: String
    let definition: String
    let example: String?

    init(partOfSpeech: String, definition: String) {
        self.id = UUID()
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.example = nil
    }

}

private enum DictionaryLookupError: LocalizedError {
    case wordNotFound
    case unavailable

    var errorDescription: String? {
        switch self {
        case .wordNotFound:
            "Try checking the spelling or searching for another word."
        case .unavailable:
            "The dictionary is temporarily unavailable. Please try again."
        }
    }
}
