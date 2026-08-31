import Foundation

enum FuzzyMatcher {
    struct Match: Sendable {
        let entry: LexiconEntry
        let distance: Int
        let kind: Candidate.Source
    }

    /// Neighbor-key and missing-key (deletion) fuzzy match against lexicon.
    static func fuzzy(
        digits: String,
        lexicon: DictionaryLoader,
        maxDistance: Int = 1,
        limit: Int = 30
    ) -> [Match] {
        guard digits.count >= 2 else { return [] }

        var matches: [Match] = []
        let exactSet = Set(lexicon.exact(digits: digits).map(\.t9))

        // 1) Neighbor substitution at one position
        if maxDistance >= 1 {
            for (i, ch) in digits.enumerated() {
                guard let neigh = T9KeyMap.neighbors[ch] else { continue }
                for n in neigh {
                    var mutated = Array(digits)
                    mutated[i] = n
                    let cand = String(mutated)
                    for e in lexicon.exact(digits: cand) where !exactSet.contains(e.t9) {
                        matches.append(Match(entry: e, distance: 1, kind: .fuzzyNeighbor))
                    }
                    // Also prefix-complete: entries whose t9 == cand or longer with same length preference
                    for e in lexicon.candidates(forDigits: cand, limit: 8) where e.t9.count == cand.count {
                        matches.append(Match(entry: e, distance: 1, kind: .fuzzyNeighbor))
                    }
                }
            }
        }

        // 2) Missing key (user omitted one digit): lexicon has one extra digit somewhere
        //    Query is a subsequence of entry.t9 with distance 1 (one deletion from entry).
        if maxDistance >= 1 {
            let probes = insertionProbes(digits)
            for probe in probes {
                for e in lexicon.exact(digits: probe) {
                    matches.append(Match(entry: e, distance: 1, kind: .fuzzyMissing))
                }
            }
        }

        // Dedup by word+reading, keep best
        var best: [String: Match] = [:]
        for m in matches {
            let k = m.entry.word + "\t" + m.entry.reading
            if let existing = best[k] {
                if m.distance < existing.distance
                    || (m.distance == existing.distance && m.entry.weight > existing.entry.weight) {
                    best[k] = m
                }
            } else {
                best[k] = m
            }
        }
        return Array(best.values)
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return lhs.entry.weight > rhs.entry.weight
            }
            .prefix(limit)
            .map { $0 }
    }

    /// All strings formed by inserting one T9 key into `digits`.
    private static func insertionProbes(_ digits: String) -> [String] {
        let keys: [Character] = Array("0123456789v")
        var out: [String] = []
        let chars = Array(digits)
        for i in 0...chars.count {
            for k in keys {
                var c = chars
                c.insert(k, at: i)
                out.append(String(c))
            }
        }
        return out
    }
}
