import Foundation
import Combine

@MainActor
final class InputEngine: ObservableObject {
    @Published private(set) var composingDigits: String = ""
    @Published private(set) var composingTones: String = ""
    @Published private(set) var candidates: [Candidate] = []
    @Published private(set) var preeditDisplay: String = ""
    @Published private(set) var lastCommitted: String = ""

    private let lexicon = DictionaryLoader()
    private let userLexicon: UserLexicon
    private var loaded = false

    init(userLexicon: UserLexicon = UserLexicon()) {
        self.userLexicon = userLexicon
    }

    func prepare(bundle: Bundle = .main) {
        guard !loaded else { return }
        do {
            try lexicon.loadFromBundle(bundle: bundle)
            loaded = true
        } catch {
            let fm = FileManager.default
            let dirs = [
                URL(fileURLWithPath: "Resources/rime"),
                URL(fileURLWithPath: "../Resources/rime"),
                URL(fileURLWithPath: "../../Resources/rime"),
            ]
            for dir in dirs where fm.fileExists(atPath: dir.path) {
                let urls = ["taiwan_phrases.dict.yaml", "bopomofo_t9.dict.yaml"]
                    .map { dir.appendingPathComponent($0) }
                    .filter { fm.fileExists(atPath: $0.path) }
                if !urls.isEmpty {
                    try? lexicon.load(from: urls)
                    loaded = true
                    break
                }
            }
        }
        refreshCandidates()
    }

    func load(from urls: [URL]) throws {
        try lexicon.load(from: urls)
        loaded = true
        refreshCandidates()
    }

    func tapT9Key(_ key: Character) {
        composingDigits.append(key)
        refreshCandidates()
    }

    func tapTone(_ tone: Character) {
        if composingTones.count >= syllableEstimate(for: composingDigits), !composingTones.isEmpty {
            composingTones.removeLast()
        }
        composingTones.append(tone)
        refreshCandidates()
    }

    func tapExactToken(_ token: Character) {
        if let key = T9KeyMap.tokenToKey[token] {
            composingDigits.append(key)
        }
        refreshCandidates()
    }

    func backspace() {
        if !composingTones.isEmpty {
            composingTones.removeLast()
        } else if !composingDigits.isEmpty {
            composingDigits.removeLast()
        }
        refreshCandidates()
    }

    func clearComposing() {
        composingDigits = ""
        composingTones = ""
        candidates = []
        preeditDisplay = ""
    }

    func selectCandidate(_ candidate: Candidate) -> String {
        let text = candidate.text
        userLexicon.recordCommit(text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
        lastCommitted = text
        clearComposing()
        let preds = userLexicon.predictions(after: text)
        candidates = preds.enumerated().map { idx, w in
            Candidate(id: "pred-\(idx)-\(w)", text: w, reading: "", score: 1000 - Double(idx), source: .prediction)
        }
        return text
    }

    func insertPassthroughAndClear(_ text: String) -> String {
        clearComposing()
        return text
    }

    func handleSpace() -> String { insertPassthroughAndClear(" ") }
    func handleReturn() -> String { insertPassthroughAndClear("\n") }
    func handleSymbol(_ symbol: String) -> String { insertPassthroughAndClear(symbol) }

    // MARK: - Ranking (Hamster / rime.lua oriented)

    private func refreshCandidates() {
        preeditDisplay = composingDigits.isEmpty
            ? ""
            : composingDigits.map { T9KeyMap.keyLabels[$0] ?? String($0) }.joined(separator: "·")

        guard !composingDigits.isEmpty else {
            if !lastCommitted.isEmpty {
                let preds = userLexicon.predictions(after: lastCommitted)
                candidates = preds.enumerated().map { idx, w in
                    Candidate(id: "pred-\(idx)-\(w)", text: w, reading: "", score: 1000 - Double(idx), source: .prediction)
                }
            } else {
                candidates = []
            }
            return
        }

        var items: [T9SortFilter.Item] = []
        let digits = composingDigits
        let inputStream = T9SortFilter.combinedInput(digits: digits, tones: composingTones)

        // 1) Every exact span that is a prefix of the digit stream (Rime partials)
        for (span, entries) in lexicon.prefixSpans(of: digits) {
            for e in entries {
                let toneBonus = toneScore(tones: e.tones)
                let userBoost = userLexicon.boost(for: e.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
                let score = Double(e.weight) + toneBonus + userBoost
                let cand = Candidate(
                    id: "span-\(span)-\(e.word)-\(e.reading)",
                    text: e.word,
                    reading: e.reading,
                    score: score,
                    source: .exact
                )
                items.append(T9SortFilter.Item(
                    candidate: cand,
                    coverage: span.count,
                    fullCoverage: span.count == digits.count,
                    orphanTone: false
                ))
            }
        }

        // 2) Full-buffer phrase + N-best segmentations
        if let phrase = PhraseSegmenter.bestPhrase(digits: digits, lexicon: lexicon) {
            let toneBonus = toneScore(tones: phrase.tones)
            let userBoost = userLexicon.boost(for: phrase.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            items.append(T9SortFilter.Item(
                candidate: Candidate(
                    id: "ph-\(phrase.word)-\(phrase.reading)",
                    text: phrase.word,
                    reading: phrase.reading,
                    score: Double(phrase.weight) + 500 + toneBonus + userBoost,
                    source: .exact
                ),
                coverage: digits.count,
                fullCoverage: true,
                orphanTone: false
            ))
        }

        for (pi, path) in PhraseSegmenter.nBest(digits: digits, lexicon: lexicon, limit: 8).enumerated() {
            let toneBonus = toneScore(tones: path.tones)
            let userBoost = userLexicon.boost(for: path.text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            // Prefer fewer segments among full-coverage paths
            let segPenalty = Double(max(0, path.entries.count - 1)) * 200
            items.append(T9SortFilter.Item(
                candidate: Candidate(
                    id: "seg-\(pi)-\(path.text)",
                    text: path.text,
                    reading: path.reading,
                    score: Double(path.weight) + toneBonus + userBoost - segPenalty,
                    source: .exact
                ),
                coverage: digits.count,
                fullCoverage: true,
                orphanTone: false
            ))
            // Also expose the first segment alone (segment-select UX like Rime)
            if let first = path.entries.first, path.entries.count > 1 {
                items.append(T9SortFilter.Item(
                    candidate: Candidate(
                        id: "seg1-\(pi)-\(first.word)",
                        text: first.word,
                        reading: first.reading,
                        score: Double(first.weight) + toneScore(tones: first.tones) + userLexicon.boost(for: first.word, previous: lastCommitted.isEmpty ? nil : lastCommitted),
                        source: .exact
                    ),
                    coverage: first.t9.count,
                    fullCoverage: false,
                    orphanTone: false
                ))
            }
        }

        // 3) Light fuzzy (neighbor / missing) — marked as non-full unless exact length
        for m in FuzzyMatcher.fuzzy(digits: digits, lexicon: lexicon, maxDistance: 1, limit: 12) {
            let toneBonus = toneScore(tones: m.entry.tones) * 0.5
            let userBoost = userLexicon.boost(for: m.entry.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            items.append(T9SortFilter.Item(
                candidate: Candidate(
                    id: "fz-\(m.entry.word)-\(m.entry.reading)",
                    text: m.entry.word,
                    reading: m.entry.reading,
                    score: Double(m.entry.weight) * 0.45 + toneBonus + userBoost - Double(m.distance) * 300,
                    source: m.kind
                ),
                coverage: m.entry.t9.count,
                fullCoverage: m.entry.t9.count == digits.count && m.distance == 0,
                orphanTone: false
            ))
        }

        // Within each raw group, prefer higher score before t9_sort_filter order
        items.sort { $0.candidate.score > $1.candidate.score }

        let sorted = T9SortFilter.sort(items: items, inputDigitsAndTones: inputStream)
        candidates = Array(sorted.prefix(12))
    }

    /// Tone match/mismatch. Decisive when user typed tones (Hamster tone filter).
    private func toneScore(tones entryTones: String) -> Double {
        guard !composingTones.isEmpty else { return 0 }
        let wanted = Array(composingTones)
        let have = Array(entryTones.filter { $0 != "-" })
        guard !have.isEmpty else { return -100 }
        var bonus: Double = 0
        for (offset, w) in wanted.reversed().enumerated() {
            if offset >= have.count {
                bonus -= 500
                continue
            }
            let h = have[have.count - 1 - offset]
            bonus += (w == h) ? 12_000 : -18_000
        }
        return bonus
    }

    private func syllableEstimate(for digits: String) -> Int {
        max(1, (digits.count + 1) / 2)
    }
}
