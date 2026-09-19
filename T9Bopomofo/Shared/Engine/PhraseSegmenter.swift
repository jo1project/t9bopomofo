import Foundation

/// Greedy + limited N-best segmentation over T9 digits.
enum PhraseSegmenter {
    struct Path {
        let entries: [LexiconEntry]
        /// Min entry weight, kept incrementally: sort comparators read this thousands of times
        /// per keystroke, so it must not rebuild an array on every access.
        let weight: Int
        var text: String { entries.map(\.word).joined() }
        var reading: String { entries.map(\.reading).joined(separator: " ") }
        var tones: String { entries.map(\.tones).joined() }
        var syllableLengths: String { entries.map(\.syllableLengths).joined() }

        static let empty = Path(entries: [], weight: 0)

        private init(entries: [LexiconEntry], weight: Int) {
            self.entries = entries
            self.weight = weight
        }

        func appending(_ e: LexiconEntry) -> Path {
            Path(entries: entries + [e], weight: entries.isEmpty ? e.weight : min(weight, e.weight))
        }
    }

    static func greedy(digits: String, lexicon: DictionaryLoader, maxWordKeys: Int = 12) -> [LexiconEntry] {
        nBest(digits: digits, lexicon: lexicon, limit: 1, maxWordKeys: maxWordKeys).first?.entries ?? []
    }

    static func bestPhrase(digits: String, lexicon: DictionaryLoader) -> LexiconEntry? {
        lexicon.exact(digits: digits).first
            ?? lexicon.candidates(forDigits: digits, limit: 20).first { $0.t9 == digits }
    }

    /// Beam search for alternative segmentations (e.g. 不是+不行 vs 不是+不幸).
    static func nBest(
        digits: String,
        lexicon: DictionaryLoader,
        limit: Int = 6,
        maxWordKeys: Int = 12
    ) -> [Path] {
        guard !digits.isEmpty else { return [] }

        // dp[i] = best paths covering digits[0..<i]
        var dp: [[Path]] = Array(repeating: [], count: digits.count + 1)
        dp[0] = [Path.empty]

        for i in 0..<digits.count {
            guard !dp[i].isEmpty else { continue }
            let rest = String(digits.dropFirst(i))
            let upper = min(maxWordKeys, rest.count)
            var hits: [LexiconEntry] = []
            for len in stride(from: upper, through: 1, by: -1) {
                let slice = String(rest.prefix(len))
                let exact = lexicon.exact(digits: slice)
                if !exact.isEmpty {
                    // Same T9 key covers several zhuyin symbols (e.g. ㄔㄘㄣㄧ on key 6), so a
                    // short span can have hundreds of same-digit, different-tone homophones.
                    // Keep a generous slice by raw weight — tone scoring is applied later by
                    // the caller and can't rescue a homophone that got cut here first.
                    hits.append(contentsOf: exact.prefix(60))
                }
            }
            // Dedup by word+reading keep highest weight
            var uniq: [String: LexiconEntry] = [:]
            for h in hits {
                let k = h.word + "\t" + h.reading
                if let e = uniq[k] {
                    if h.weight > e.weight { uniq[k] = h }
                } else {
                    uniq[k] = h
                }
            }
            let options = Array(uniq.values)

            for prev in dp[i] {
                for hit in options {
                    let nextIndex = i + hit.t9.count
                    guard nextIndex <= digits.count else { continue }
                    dp[nextIndex].append(prev.appending(hit))
                }
            }
            // Cap beam at each position
            for j in (i + 1)...min(digits.count, i + maxWordKeys) {
                if dp[j].count > 24 {
                    dp[j].sort { $0.weight > $1.weight }
                    dp[j] = Array(dp[j].prefix(12))
                }
            }
        }

        var finals = dp[digits.count]
        // Prefer fewer segments, then higher min weight
        finals.sort { a, b in
            if a.entries.count != b.entries.count { return a.entries.count < b.entries.count }
            return a.weight > b.weight
        }
        // Dedup by surface text
        var seen = Set<String>()
        var out: [Path] = []
        for p in finals {
            if seen.insert(p.text).inserted {
                out.append(p)
            }
            if out.count >= limit { break }
        }
        return out
    }
}
