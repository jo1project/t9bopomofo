import Foundation

/// Greedy longest-match segmentation over T9 digits for continuous phrase input.
enum PhraseSegmenter {
    struct Segment {
        let entry: LexiconEntry
        let consumed: Int
    }

    static func greedy(digits: String, lexicon: DictionaryLoader, maxWordKeys: Int = 12) -> [LexiconEntry] {
        var i = digits.startIndex
        var out: [LexiconEntry] = []
        while i < digits.endIndex {
            let rest = String(digits[i...])
            var best: LexiconEntry?
            var bestLen = 0
            let upper = min(maxWordKeys, rest.count)
            for len in stride(from: upper, through: 1, by: -1) {
                let slice = String(rest.prefix(len))
                if let hit = lexicon.exact(digits: slice).first {
                    best = hit
                    bestLen = len
                    break
                }
            }
            if let best, bestLen > 0 {
                out.append(best)
                i = digits.index(i, offsetBy: bestLen)
            } else {
                // skip one key to avoid infinite loop
                i = digits.index(after: i)
            }
        }
        return out
    }

    /// Best single-span phrase covering the whole digit string (or longest prefix phrase).
    static func bestPhrase(digits: String, lexicon: DictionaryLoader) -> LexiconEntry? {
        lexicon.exact(digits: digits).first
            ?? lexicon.candidates(forDigits: digits, limit: 20).first { $0.t9 == digits }
    }
}
