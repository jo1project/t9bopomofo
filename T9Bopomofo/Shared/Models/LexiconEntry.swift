import Foundation

struct LexiconEntry: Hashable, Sendable {
    let word: String
    let reading: String
    /// T9 digit sequence without tones.
    let t9: String
    /// Per-syllable tone markers (q/w/x/y/-), same length as syllable count.
    let tones: String
    /// T9 digit count of each syllable, in reading order. Sum equals `t9.count`.
    /// Lets tone scoring match a typed tone to the exact syllable it was pressed
    /// for (by composing-digit position), instead of guessing from press order.
    let syllableLengths: [Int]
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
