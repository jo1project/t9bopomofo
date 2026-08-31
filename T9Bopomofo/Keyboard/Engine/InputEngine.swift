import Foundation
import Combine

/// Keyboard-facing input engine. Prefers librime; falls back to Swift T9 matcher.
@MainActor
final class InputEngine: ObservableObject {
    @Published private(set) var composingDigits: String = ""
    @Published private(set) var composingTones: String = ""
    @Published private(set) var candidates: [Candidate] = []
    @Published private(set) var preeditDisplay: String = ""
    @Published private(set) var lastCommitted: String = ""
    @Published private(set) var usingRime: Bool = false

    private let lexicon = DictionaryLoader()
    private let userLexicon: UserLexicon
    private let rime = RimeEngine.shared
    private var loaded = false

    init(userLexicon: UserLexicon = UserLexicon()) {
        self.userLexicon = userLexicon
    }

    func prepare(bundle: Bundle = .main) {
        if !usingRime {
            usingRime = rime.start(bundle: bundle)
        }
        if usingRime {
            syncFromRime()
            return
        }
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
        refreshSwiftCandidates()
    }

    func load(from urls: [URL]) throws {
        try lexicon.load(from: urls)
        loaded = true
        refreshSwiftCandidates()
    }

    var isComposing: Bool {
        if usingRime { return rime.isComposing || !rime.input.isEmpty }
        return !composingDigits.isEmpty || !composingTones.isEmpty
    }

    func tapT9Key(_ key: Character) {
        if usingRime {
            _ = rime.processKey(key)
            syncFromRime()
            return
        }
        composingDigits.append(key)
        refreshSwiftCandidates()
    }

    func tapTone(_ tone: Character) {
        if usingRime {
            _ = rime.processKey(tone)
            syncFromRime()
            return
        }
        if composingTones.count >= syllableEstimate(for: composingDigits), !composingTones.isEmpty {
            composingTones.removeLast()
        }
        composingTones.append(tone)
        refreshSwiftCandidates()
    }

    func tapExactToken(_ token: Character) {
        if usingRime {
            // Send schema letter (b/g/Z/…) directly — finer than T9 digit.
            _ = rime.processKey(token)
            syncFromRime()
            return
        }
        if let key = T9KeyMap.tokenToKey[token] {
            composingDigits.append(key)
        }
        refreshSwiftCandidates()
    }

    func backspace() {
        if usingRime {
            rime.backspace()
            syncFromRime()
            return
        }
        if !composingTones.isEmpty {
            composingTones.removeLast()
        } else if !composingDigits.isEmpty {
            composingDigits.removeLast()
        }
        refreshSwiftCandidates()
    }

    func clearComposing() {
        if usingRime {
            rime.clearComposition()
            syncFromRime()
            return
        }
        composingDigits = ""
        composingTones = ""
        candidates = []
        preeditDisplay = ""
    }

    func selectCandidate(_ candidate: Candidate) -> String {
        if usingRime {
            // Candidate.id for Rime is "rime-<index>"
            let idx: Int = {
                if candidate.id.hasPrefix("rime-"),
                   let n = Int(candidate.id.dropFirst(5)) {
                    return n
                }
                return candidates.firstIndex(where: { $0.id == candidate.id }) ?? 0
            }()
            let text = rime.selectCandidate(at: idx)
            if !text.isEmpty {
                userLexicon.recordCommit(text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
                lastCommitted = text
            }
            syncFromRime()
            return text
        }

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

    // MARK: - Rime sync

    private func syncFromRime() {
        let input = rime.input
        composingDigits = input
        composingTones = String(input.filter { T9KeyMap.toneKeys.contains($0) })

        let pre = rime.preedit
        if !pre.isEmpty {
            preeditDisplay = pre
        } else if input.isEmpty {
            preeditDisplay = ""
        } else {
            preeditDisplay = input.map { T9KeyMap.keyLabels[$0] ?? String($0) }.joined(separator: "·")
        }

        let raw = rime.candidates(limit: 12)
        if raw.isEmpty, !lastCommitted.isEmpty, input.isEmpty {
            let preds = userLexicon.predictions(after: lastCommitted)
            candidates = preds.enumerated().map { idx, w in
                Candidate(id: "pred-\(idx)-\(w)", text: w, reading: "", score: 1000 - Double(idx), source: .prediction)
            }
        } else {
            candidates = raw.enumerated().map { idx, item in
                Candidate(
                    id: "rime-\(idx)",
                    text: item.text,
                    reading: item.comment,
                    score: Double(1000 - idx),
                    source: .exact
                )
            }
        }
    }

    // MARK: - Swift fallback ranking

    private func refreshSwiftCandidates() {
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

        items.sort { $0.candidate.score > $1.candidate.score }
        let sorted = T9SortFilter.sort(items: items, inputDigitsAndTones: inputStream)
        candidates = Array(sorted.prefix(12))
    }

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
