import Foundation

/// Offline list of playable Quiddler words.
///
/// `QuiddlerWords.txt` is the public-domain ENABLE word list: lowercase
/// English words with no proper nouns, abbreviations, prefixes, suffixes,
/// hyphens or apostrophes, which matches the Quiddler rules on allowable words.
nonisolated enum QuiddlerWordList {
    static let sourceName = "ENABLE word list"

    /// ENABLE plus `QuiddlerModernWords.txt`, everyday words added to standard
    /// dictionaries since ENABLE was compiled (email, app, selfie, qi, za).
    private static let words: Set<String> = {
        let enable = load("QuiddlerWords")
        return enable.isEmpty ? [] : enable.union(load("QuiddlerModernWords"))
    }()

    private static func load(_ name: String) -> Set<String> {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return Set(text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) })
    }

    /// False only if the bundled list is missing from the app.
    static var isAvailable: Bool { !words.isEmpty }

    static func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }

    /// Loads the list ahead of the first lookup so it doesn't stall the UI.
    static func preload() async {
        await Task.detached(priority: .utility) { _ = words.count }.value
    }
}
