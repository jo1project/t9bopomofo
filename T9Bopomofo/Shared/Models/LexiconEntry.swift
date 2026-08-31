import Foundation

struct LexiconEntry: Hashable, Sendable {
    let word: String
    let reading: String
    /// T9 digit sequence without tones.
    let t9: String
    /// Per-syllable tone markers (q/w/x/y/-), same length as syllable count.
    let tones: String
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
    }
}
