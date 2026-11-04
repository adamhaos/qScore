import Foundation

struct DictionaryEntry: Codable, Identifiable {
    var id: String { word.lowercased() }
    let word: String
    let meanings: [DictionaryMeaning]
    let legality: QuiddlerWordLegality?
    var definitionSource: String?

    var displayPhonetic: String? { nil }

    var definitionPreview: String {
        if let definition = meanings.first?.definitions.first?.definition { return definition }
        switch resolvedLegality {
        case .legal: return "Legal word"
        case .illegal: return "Not playable"
        case .unverified, .meaningDependent: return "Check your agreed dictionary"
        }
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

enum QuiddlerWordLegality: Codable {
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

enum QuiddlerWordValidator {
    /// Lowercases a typed word and drops accents, since the cards have none
    /// (so "Café" is checked as "cafe").
    static func normalized(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    static func fallbackCheck(_ word: String) -> QuiddlerWordLegality {
        let word = normalized(word)
        if word.count < 2 {
            return .illegal("Every word must use at least two cards.")
        }

        if word.contains(where: { $0 == "-" || $0 == "‐" || $0 == "‑" }) {
            return .illegal("Hyphenated words aren’t allowed.")
        }

        if word.contains(where: \.isWhitespace) {
            return .illegal("A play must be a single word.")
        }

        if word.contains(where: { $0 == "'" || $0 == "’" || $0 == "‘" }) {
            return .illegal("Contractions and possessives aren’t allowed.")
        }

        guard word.unicodeScalars.allSatisfy({
            (65...90).contains(Int($0.value)) || (97...122).contains(Int($0.value))
        }) else {
            return .illegal("Use only letters A–Z. Punctuation and numbers can't be played.")
        }

        return .unverified("Check this word in your agreed dictionary.")
    }

    static func lookup(_ word: String) async throws -> DictionaryEntry {
        await QuiddlerWordList.preload()
        try Task.checkCancellation()
        return entry(for: word)
    }

    /// Checks a word against the bundled lists. Call after the lists have
    /// loaded (see `QuiddlerWordList.preload()`) to avoid stalling.
    static func entry(for word: String) -> DictionaryEntry {
        if case .illegal(let reason) = fallbackCheck(word) {
            return DictionaryEntry(word: word, meanings: [], legality: .illegal(reason))
        }
        let normalized = normalized(word)

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

        // The word list alone decides legality, so it works the same offline.
        // Definitions come from the iPhone's built-in dictionary on request.
        return DictionaryEntry(
            word: normalized,
            meanings: [],
            legality: .legal,
            definitionSource: QuiddlerWordList.sourceName
        )
    }
}

struct DictionaryMeaning: Codable, Identifiable {
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

struct DictionaryDefinition: Codable, Identifiable {
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
