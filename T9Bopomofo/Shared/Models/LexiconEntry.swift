import Foundation

struct LexiconEntry: Hashable, Codable, Sendable {
    let word: String
    let reading: String
    /// T9 digit sequence without tones.
    let t9: String
    /// Per-syllable tone markers (q/w/x/y/-), same length as syllable count.
    let tones: String
    /// T9 digit count of each syllable, in reading order, one ASCII digit per syllable (e.g. "21");
    /// the counts sum to `t9.count`. Lets tone scoring match a typed tone to the exact syllable it
    /// was pressed for (by composing-digit position), instead of guessing from press order.
    /// A String, not [Int]: measured, 160k separate [Int] buffers cost +6.6MB of the +12.7MB the
    /// lexicon takes in the extension; short Strings are stored inline and cost +0.0MB.
    let syllableLengths: String
    let weight: Int
}

struct Candidate: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let reading: String
    let score: Double
    let source: Source

    enum Source: String, Sendable {
        case exact
        case fuzzyNeighbor
        case fuzzyMissing
        case user
        case prediction
        case llm
    }
}
