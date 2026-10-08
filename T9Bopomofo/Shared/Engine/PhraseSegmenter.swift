import Foundation

/// Beam-search N-best segmentation over T9 digits.
enum PhraseSegmenter {
    /// One segment plus the path it extends. Appending used to copy the whole entries array:
    /// 6k-14k paths per keystroke, each copying and retaining every entry's strings.
    final class Node: Sendable {
        let entry: LexiconEntry
        let parent: Node?
        init(_ entry: LexiconEntry, parent: Node?) {
            self.entry = entry
            self.parent = parent
        }
    }

    struct Path {
        let last: Node?
        /// Segment count.
        let count: Int
        /// Min entry weight, kept incrementally: sort comparators read this thousands of times
        /// per keystroke, so it must not rebuild an array on every access.
        let weight: Int
        /// Sum of the caller's per-entry bonus (tone match), so the beam can rank by it.
        let bonus: Double
        /// Built on demand; only the handful of returned paths need it.
        var entries: [LexiconEntry] {
            var out: [LexiconEntry] = []
            out.reserveCapacity(count)
            var n = last
            while let node = n {
                out.append(node.entry)
                n = node.parent
            }
            return out.reversed()
        }
        var text: String { entries.map(\.word).joined() }
        var reading: String { entries.map(\.reading).joined(separator: " ") }
        var tones: String { entries.map(\.tones).joined() }
        var syllableLengths: String { entries.map(\.syllableLengths).joined() }

        static let empty = Path(last: nil, count: 0, weight: 0, bonus: 0)

        private init(last: Node?, count: Int, weight: Int, bonus: Double) {
            self.last = last
            self.count = count
            self.weight = weight
            self.bonus = bonus
        }

        func appending(_ e: LexiconEntry, bonus b: Double) -> Path {
            Path(last: Node(e, parent: last), count: count + 1,
                 weight: count == 0 ? e.weight : min(weight, e.weight), bonus: bonus + b)
        }

        /// Fewer segments first (real words over chops), then weight + tone bonus.
        static func better(_ a: Path, _ b: Path) -> Bool {
            if a.count != b.count { return a.count < b.count }
            return Double(a.weight) + a.bonus > Double(b.weight) + b.bonus
        }
    }

    static func bestPhrase(digits: String, lexicon: DictionaryLoader) -> LexiconEntry? {
        lexicon.exact(digits: digits).first
    }

    /// Beam search for alternative segmentations (e.g. 不是+不行 vs 不是+不幸).
    /// - Parameter bonus: extra score for an entry starting at a digit offset (tone match).
    static func nBest(
        digits: String,
        lexicon: DictionaryLoader,
        limit: Int = 6,
        maxWordKeys: Int = 12,
        beam: Int = 24,
        bonus: (LexiconEntry, Int) -> Double = { _, _ in 0 }
    ) -> [Path] {
        guard !digits.isEmpty else { return [] }
        let chars = Array(digits)

        // dp[i] = paths covering digits[0..<i]
        var dp: [[Path]] = Array(repeating: [], count: chars.count + 1)
        dp[0] = [Path.empty]

        for i in 0..<chars.count {
            guard !dp[i].isEmpty else { continue }
            // Prune before extending. Pruning after (the old way) first built up to
            // 24 paths × 720 hits per position, which was the lag on long input, and ranked
            // by raw min weight, which dropped 想 from 想一下 before tones could count.
            if dp[i].count > beam {
                dp[i] = Array(dp[i].sorted(by: Path.better).prefix(beam))
            }
            // Same T9 key covers several zhuyin symbols (e.g. ㄔㄘㄣㄧ on key 6), so a short
            // span has hundreds of homophones. Score tones before cutting per span, so the
            // homophone with the typed tone survives the cut.
            var hits: [(entry: LexiconEntry, bonus: Double)] = []
            for len in 1...min(maxWordKeys, chars.count - i) {
                let span = String(chars[i..<(i + len)])
                let scored = lexicon.exact(digits: span, limit: 120).map { ($0, bonus($0, i)) }
                hits += scored
                    .sorted { Double($0.0.weight) + $0.1 > Double($1.0.weight) + $1.1 }
                    .prefix(16)
                    .map { (entry: $0.0, bonus: $0.1) }
            }
            for prev in dp[i] {
                for hit in hits {
                    dp[i + hit.entry.t9.utf8.count].append(prev.appending(hit.entry, bonus: hit.bonus))
                }
            }
        }

        // Dedup by surface text
        var seen = Set<String>()
        var out: [Path] = []
        for p in dp[chars.count].sorted(by: Path.better) {
            if seen.insert(p.text).inserted {
                out.append(p)
            }
            if out.count >= limit { break }
        }
        return out
    }
}
