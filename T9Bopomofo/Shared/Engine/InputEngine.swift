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
            // Fallback: try relative paths for unit tests / previews
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
        // Tone applies to current unfinished syllable loosely: append marker for ranking.
        composingTones.append(tone)
        refreshCandidates()
    }

    /// Long-press exact zhuyin token (schema letter) → append its T9 key AND bias ranking.
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

    /// Confirm a candidate (explicit tap on candidate bar).
    func selectCandidate(_ candidate: Candidate) -> String {
        let text = candidate.text
        userLexicon.recordCommit(text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
        lastCommitted = text
        clearComposing()
        // After commit, show predictions
        let preds = userLexicon.predictions(after: text)
        candidates = preds.enumerated().map { idx, w in
            Candidate(id: "pred-\(idx)-\(w)", text: w, reading: "", score: 1000 - Double(idx), source: .prediction)
        }
        return text
    }

    /// Space / symbol / return: insert char, clear composing WITHOUT committing first candidate.
    func insertPassthroughAndClear(_ text: String) -> String {
        clearComposing()
        // Keep lastCommitted for context; passthrough is not a word commit.
        return text
    }

    func handleSpace() -> String {
        insertPassthroughAndClear(" ")
    }

    func handleReturn() -> String {
        insertPassthroughAndClear("\n")
    }

    func handleSymbol(_ symbol: String) -> String {
        insertPassthroughAndClear(symbol)
    }

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

        // Whole-buffer phrase / greedy segmentation (連打)
        if let phrase = PhraseSegmenter.bestPhrase(digits: composingDigits, lexicon: lexicon) {
            let userBoost = userLexicon.boost(for: phrase.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            scored.append(
                Candidate(
                    id: "ph-\(phrase.word)-\(phrase.reading)",
                    text: phrase.word,
                    reading: phrase.reading,
                    score: Double(phrase.weight) + 500 + userBoost,
                    source: .exact
                )
            )
        }
        let segments = PhraseSegmenter.greedy(digits: composingDigits, lexicon: lexicon)
        if segments.count >= 2 {
            let joined = segments.map(\.word).joined()
            let weight = segments.map(\.weight).min() ?? 0
            scored.append(
                Candidate(
                    id: "seg-\(joined)",
                    text: joined,
                    reading: segments.map(\.reading).joined(separator: " "),
                    score: Double(weight) + 300 + Double(segments.count) * 40,
                    source: .exact
                )
            )
        }

        let exact = lexicon.candidates(forDigits: composingDigits, limit: 40)
        for e in exact {
            let toneBonus = toneScore(entry: e)
            let userBoost = userLexicon.boost(for: e.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            let lengthPenalty = abs(e.t9.count - composingDigits.count) * 5
            let score = Double(e.weight) + toneBonus + userBoost - Double(lengthPenalty)
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
            let userBoost = userLexicon.boost(for: m.entry.word, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            let score = Double(m.entry.weight) * 0.55 + userBoost - Double(m.distance) * 200
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

        // Dedup by text, keep highest score
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

    private func toneScore(entry: LexiconEntry) -> Double {
        guard !composingTones.isEmpty else { return 0 }
        // Reward matching trailing tones if user typed any.
        let wanted = Array(composingTones)
        let have = Array(entry.tones.filter { $0 != "-" })
        var bonus: Double = 0
        for (a, b) in zip(wanted.reversed(), have.reversed()) {
            if a == b { bonus += 80 }
            else { bonus -= 20 }
        }
        return bonus
    }
}
