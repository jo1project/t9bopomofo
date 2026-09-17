import Foundation

/// Port of Hamster / rime-bopomofo-t9 `rime.lua` `t9_sort_filter` (v16).
///
/// Ranking goals (same as upstream):
/// 1. Full-coverage candidates first (whole phrase / sentence)
/// 2. If a tone anchors the first syllable, promote that syllable's best char
/// 3. Round-robin partial spans by coverage length (long→short each round)
/// 4. Orphan-tone breaks last (断在声调键前的无效断词)
enum T9SortFilter {
    struct Item {
        var candidate: Candidate
        /// How many composing digits this candidate consumes.
        var coverage: Int
        /// True if coverage equals the full input length.
        var fullCoverage: Bool
        /// True if the next input char after this span is a tone key (invalid break).
        var orphanTone: Bool
    }

    private static let toneKeys: Set<Character> = ["q", "w", "x", "y"]

    /// - Parameters:
    ///   - inputDigitsAndTones: digits + tones concatenated (see `combinedInput`), used only for
    ///     the orphan-tone lookahead below.
    ///   - digitsCount: T9 digit count alone. `item.coverage` is always in digit-only units (every
    ///     caller sets it that way), so full-coverage MUST compare against this, not against
    ///     `inputDigitsAndTones.count` — comparing against the combined length meant a candidate
    ///     stopped being "full" the moment any tone key was pressed (coverage no longer >= the
    ///     now-longer combined length), while FuzzyMatcher's one-digit-longer "missing key" guesses
    ///     coincidentally became "full" instead and jumped to the front.
    static func sort(items: [Item], inputDigitsAndTones: String, digitsCount: Int) -> [Candidate] {
        guard !items.isEmpty else { return [] }
        let input = Array(inputDigitsAndTones)

        var full: [Item] = []
        var buckets: [Int: [Item]] = [:]
        var orphans: [Item] = []
        var maxCov = 0

        for var item in items.prefix(80) {
            let cov = item.coverage
            item.fullCoverage = cov == digitsCount
            if !item.fullCoverage, cov < input.count {
                let next = input[cov]
                item.orphanTone = toneKeys.contains(next)
            }
            if item.fullCoverage {
                full.append(item)
            } else if item.orphanTone {
                orphans.append(item)
            } else {
                buckets[cov, default: []].append(item)
                maxCov = max(maxCov, cov)
            }
        }

        // First-syllable promote: first tone key marks end of syllable 1.
        var promoted: Item?
        if let toneIdx = input.firstIndex(where: { toneKeys.contains($0) }) {
            let cov = input.distance(from: input.startIndex, to: toneIdx)
            // coverage in digits-before-tone; our composing may interleave — use digit-only cov buckets.
            if var b = buckets[cov], !b.isEmpty {
                promoted = b.removeFirst()
                buckets[cov] = b
            }
        }

        var ordered: [Candidate] = []
        ordered.append(contentsOf: full.map(\.candidate))
        if let promoted {
            ordered.append(promoted.candidate)
        }

        var round = 0
        var emitted = true
        while emitted {
            emitted = false
            for cov in stride(from: maxCov, through: 1, by: -1) {
                guard let b = buckets[cov], round < b.count else { continue }
                ordered.append(b[round].candidate)
                emitted = true
            }
            round += 1
            if round > 40 { break }
        }

        ordered.append(contentsOf: orphans.map(\.candidate))

        // Dedup by text keeping first (higher priority) occurrence
        var seen = Set<String>()
        var out: [Candidate] = []
        for c in ordered {
            if seen.insert(c.text).inserted {
                out.append(c)
            }
        }
        return out
    }

    /// Find first tone position treating composingDigits + composingTones as Rime input stream.
    /// Our engine stores tones separately; approximate by appending tones at end for orphan checks,
    /// and using digit coverage for spans.
    static func combinedInput(digits: String, tones: String) -> String {
        // Rime streams tones inline after each syllable; we only know trailing tones.
        // For orphan detection on partial spans, append typed tones at the end.
        digits + tones
    }
}
