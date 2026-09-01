import Foundation

/// Greedy + limited N-best segmentation over T9 digits.
enum PhraseSegmenter {
    struct Path {
        let entries: [LexiconEntry]
        var text: String { entries.map(\.word).joined() }
        var reading: String { entries.map(\.reading).joined(separator: " ") }
        var weight: Int { entries.map(\.weight).min() ?? 0 }
        var tones: String { entries.map(\.tones).joined() }
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
        dp[0] = [Path(entries: [])]

        for i in 0..<digits.count {
            guard !dp[i].isEmpty else { continue }
            let rest = String(digits.dropFirst(i))
            let upper = min(maxWordKeys, rest.count)
            var hits: [LexiconEntry] = []
            for len in stride(from: upper, through: 1, by: -1) {
                let slice = String(rest.prefix(len))
                let exact = lexicon.exact(digits: slice)
                if !exact.isEmpty {
                    // Keep top few homophones at this span
                    hits.append(contentsOf: exact.prefix(4))
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
                    var entries = prev.entries
                    entries.append(hit)
                    let path = Path(entries: entries)
                    dp[nextIndex].append(path)
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
