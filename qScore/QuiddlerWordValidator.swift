import Foundation

struct DictionaryEntry: Codable, Identifiable {
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
    private static let allowableHeadings = [
        "noun", "verb", "adjective", "adverb", "pronoun", "preposition",
        "conjunction", "interjection", "determiner", "article", "numeral"
    ]

    /// Lowercases a typed word and drops accents, since the cards have none
    /// (so "Café" is checked as "cafe").
    static func normalized(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
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
        if case .illegal(let reason) = fallbackCheck(word) {
            return DictionaryEntry(word: word, meanings: [], legality: .illegal(reason))
        }
        let normalized = normalized(word)

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

struct WiktionaryMeaning: Decodable {
    let partOfSpeech: String
    let language: String
    let definitions: [WiktionarySense]
}

struct WiktionarySense: Decodable {
    let definition: String
}

final class DictionaryHTMLText: NSObject, XMLParserDelegate {
    private var text = ""
    /// How many open elements deep we are inside markup whose text isn't
    /// part of the definition, such as inline CSS or "[from 15th c.]" dates.
    private var skipDepth = 0

    static func plainText(_ html: String) -> String? {
        let fragment = html
            .replacingOccurrences(of: #"<(?:link|br|hr|img|meta|input|wbr)\b[^>]*>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "&nbsp;", with: "&#160;")
            .replacingOccurrences(of: "&ndash;", with: "&#8211;")
            .replacingOccurrences(of: "&mdash;", with: "&#8212;")
        let parser = XMLParser(data: Data(("<root>" + fragment + "</root>").utf8))
        parser.shouldResolveExternalEntities = false
        let reader = DictionaryHTMLText()
        parser.delegate = reader
        // Markup XMLParser can't read still has a usable definition in it.
        let text = parser.parse() ? reader.text : strippingTags(fragment)
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func strippingTags(_ fragment: String) -> String {
        fragment
            .replacingOccurrences(of: #"<(style|script)\b[^>]*>.*?</\1>"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<span[^>]*\bdefdate\b[^>]*>[^<]*</span>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&#160;", with: " ")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        let classes = attributes["class"]?.split(separator: " ") ?? []
        if skipDepth > 0 || ["style", "script"].contains(elementName.lowercased()) || classes.contains("defdate") {
            skipDepth += 1
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if skipDepth > 0 { skipDepth -= 1 }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard skipDepth == 0 else { return }
        text += string
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

enum DictionaryLookupError: LocalizedError {
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
