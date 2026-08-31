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
            let candidates = [
                URL(fileURLWithPath: "Resources/rime"),
                URL(fileURLWithPath: "../Resources/rime"),
                URL(fileURLWithPath: "../../Resources/rime"),
            ]
            for dir in candidates where fm.fileExists(atPath: dir.path) {
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

    // MARK: - Input

    func tapT9Key(_ key: Character) {
        composingDigits.append(key)
        refreshCandidates()
    }

    func tapTone(_ tone: Character) {
        // Tone applies to the *current last syllable* (replace if already set for that slot).
        if composingTones.count >= syllableEstimate(for: composingDigits) {
            if !composingTones.isEmpty {
                composingTones.removeLast()
            }
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

    // MARK: - Ranking

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

        var scored: [Candidate] = []

        if let phrase = PhraseSegmenter.bestPhrase(digits: composingDigits, lexicon: lexicon) {
            let toneBonus = toneScore(tones: phrase.tones)
            let userBoost = userLexicon.boost(for: phrase.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            // Whole-buffer hit must beat short-word chops (號+臘xi1+食).
            scored.append(
                Candidate(
                    id: "ph-\(phrase.word)-\(phrase.reading)",
                    text: phrase.word,
                    reading: phrase.reading,
                    score: Double(phrase.weight) + 20_000 + toneBonus + userBoost,
                    source: .exact
                )
            )
        }

        let paths = PhraseSegmenter.nBest(digits: composingDigits, lexicon: lexicon, limit: 8)
        for (pi, path) in paths.enumerated() where path.entries.count >= 1 {
            let toneBonus = toneScore(tones: path.tones)
            let userBoost = userLexicon.boost(for: path.text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            // Prefer fewer, longer segments. Penalize 3+ char chops hard.
            let segPenalty = Double(path.entries.count - 1) * 8_000
            let lengthCover = Double(path.entries.map(\.word.count).reduce(0, +)) * 30
            scored.append(
                Candidate(
                    id: "seg-\(pi)-\(path.text)",
                    text: path.text,
                    reading: path.reading,
                    score: Double(path.weight) + lengthCover + toneBonus + userBoost - segPenalty - Double(pi) * 20,
                    source: .exact
                )
            )
        }

        let exact = lexicon.candidates(forDigits: composingDigits, limit: 40)
        for e in exact {
            let toneBonus = toneScore(tones: e.tones)
            let userBoost = userLexicon.boost(for: e.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            let exactLenBonus = e.t9 == composingDigits ? 15_000.0 : 0
            let lengthPenalty = abs(e.t9.count - composingDigits.count) * 80
            let score = Double(e.weight) + exactLenBonus + toneBonus + userBoost - Double(lengthPenalty)
            scored.append(
                Candidate(
                    id: "ex-\(e.word)-\(e.reading)",
                    text: e.word,
                    reading: e.reading,
                    score: score,
                    source: .exact
                )
            )
        }

        let fuzzy = FuzzyMatcher.fuzzy(digits: composingDigits, lexicon: lexicon, maxDistance: 1, limit: 20)
        for m in fuzzy {
            let toneBonus = toneScore(tones: m.entry.tones) * 0.5
            let userBoost = userLexicon.boost(for: m.entry.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            let score = Double(m.entry.weight) * 0.55 + toneBonus + userBoost - Double(m.distance) * 200
            scored.append(
                Candidate(
                    id: "fz-\(m.entry.word)-\(m.entry.reading)",
                    text: m.entry.word,
                    reading: m.entry.reading,
                    score: score,
                    source: m.kind
                )
            )
        }

        var best: [String: Candidate] = [:]
        for c in scored {
            if let existing = best[c.text] {
                if c.score > existing.score { best[c.text] = c }
            } else {
                best[c.text] = c
            }
        }
        candidates = best.values.sorted { $0.score > $1.score }.prefix(12).map { $0 }
    }

    /// Strong tone match on trailing syllables. Second tone on 行 must beat 幸.
    private func toneScore(tones entryTones: String) -> Double {
        guard !composingTones.isEmpty else { return 0 }
        let wanted = Array(composingTones)
        let have = Array(entryTones.filter { $0 != "-" })
        guard !have.isEmpty else { return -100 }
        var bonus: Double = 0
        // Align from the end: last typed tone ↔ last syllable
        for (offset, w) in wanted.reversed().enumerated() {
            if offset >= have.count {
                bonus -= 150
                continue
            }
            let h = have[have.count - 1 - offset]
            if w == h {
                bonus += 900  // decisive
            } else {
                bonus -= 700
            }
        }
        return bonus
    }

    private func syllableEstimate(for digits: String) -> Int {
        // Rough: most syllables are 1–3 T9 keys; use tone slots ≈ digit_len/2 capped.
        max(1, (digits.count + 1) / 2)
    }
}
