import Foundation
import Combine

/// Keyboard-facing input engine: Swift T9 matcher over the chewing-derived lexicon.
@MainActor
final class InputEngine: ObservableObject {
    @Published private(set) var composingDigits: String = ""
    @Published private(set) var composingTones: String = ""
    @Published private(set) var candidates: [Candidate] = []
    @Published private(set) var preeditDisplay: String = ""
    @Published private(set) var lastCommitted: String = ""
    /// Shown in candidate bar when idle (LLM loading / errors / hints).
    @Published private(set) var predictionStatus: String = ""

    private let lexicon = DictionaryLoader()
    private let userLexicon: UserLexicon
    /// Each tone key press, tagged with `composingDigits.count` at the moment it was pressed —
    /// lets tone scoring match a press to the exact syllable it was meant for (by digit
    /// position) instead of assuming presses arrive in strict per-syllable left-to-right order.
    private var toneMarks: [(digits: Int, tone: Character)] = []
    private var candidateLimit = 40  // ponytail: 12->40 so rare chars appear
    private var llmTask: Task<Void, Never>?
    private var lastPredictionContext: String = ""

    /// Fired on main when candidates change (e.g. async LLM).
    var onCandidatesChanged: (() -> Void)?

    init(userLexicon: UserLexicon = UserLexicon()) {
        self.userLexicon = userLexicon
    }

    func setCandidateLimit(_ limit: Int) {
        candidateLimit = max(8, limit)
        refreshSwiftCandidates()
    }

    /// DictionaryLoader.loadFromBundle() just locates the (sharded) bundle resources —
    /// it doesn't decode anything yet, so this is cheap enough to call synchronously here.
    /// Actual dictionary data loads lazily, one T9-first-digit shard at a time, the first
    /// time a query touches it (see DictionaryLoader.ensureShardLoaded) — no more background
    /// queue, no more "not loaded yet" state to gate reads against.
    func prepare(bundle: Bundle = .main) {
        if (try? lexicon.loadFromBundle(bundle: bundle)) == nil {
            let fm = FileManager.default
            let dirs = [
                URL(fileURLWithPath: "Resources/chewing"),
                URL(fileURLWithPath: "../Resources/chewing"),
                URL(fileURLWithPath: "../../Resources/chewing"),
            ]
            for dir in dirs where fm.fileExists(atPath: dir.path) {
                let urls = ["taiwan_phrases.dict.yaml", "chewing_base.dict.yaml"]
                    .map { dir.appendingPathComponent($0) }
                    .filter { fm.fileExists(atPath: $0.path) }
                if !urls.isEmpty {
                    try? lexicon.load(from: urls)
                    break
                }
            }
        }
        refreshSwiftCandidates()
    }

    func load(from urls: [URL]) throws {
        try lexicon.load(from: urls)
        refreshSwiftCandidates()
    }

    var isComposing: Bool {
        !composingDigits.isEmpty || !composingTones.isEmpty
    }

    func tapT9Key(_ key: Character) {
        composingDigits.append(key)
        refreshSwiftCandidates()
    }

    func tapTone(_ tone: Character) {
        // A second tone press with no digits typed in between targets the same syllable
        // (the user changed their mind) — replace rather than stack a second mark on it.
        if let last = toneMarks.last, last.digits == composingDigits.count {
            toneMarks.removeLast()
        }
        toneMarks.append((digits: composingDigits.count, tone: tone))
        composingTones = String(toneMarks.map(\.tone))
        refreshSwiftCandidates()
    }

    func tapExactToken(_ token: Character) {
        if let key = T9KeyMap.tokenToKey[token] {
            composingDigits.append(key)
        }
        refreshSwiftCandidates()
    }

    func backspace() {
        if !toneMarks.isEmpty {
            toneMarks.removeLast()
            composingTones = String(toneMarks.map(\.tone))
        } else if !composingDigits.isEmpty {
            composingDigits.removeLast()
        }
        refreshSwiftCandidates()
    }

    func clearComposing() {
        composingDigits = ""
        composingTones = ""
        toneMarks = []
        candidates = []
        preeditDisplay = ""
    }

    func selectCandidate(_ candidate: Candidate) -> String {
        // Next-word suggestions (local / LLM) are not lexicon candidates.
        if candidate.source == .prediction || candidate.source == .llm
            || candidate.id.hasPrefix("pred-") || candidate.id.hasPrefix("llm-") {
            return commitSuggestion(candidate.text)
        }
        return commitSuggestion(candidate.text)
    }

    /// Writes pending user-dictionary changes; the keyboard is going away.
    func flushUserLexicon() { userLexicon.flush() }

    private func commitSuggestion(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        userLexicon.recordCommit(text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
        lastCommitted = text
        lastPredictionContext = text
        clearComposing()
        applyLocalPredictions(after: text)
        return text
    }

    private func applyLocalPredictions(after text: String) {
        let preds = userLexicon.predictions(after: text)
        candidates = preds.enumerated().map { idx, w in
            Candidate(id: "pred-\(idx)-\(w)", text: w, reading: "", score: 1000 - Double(idx), source: .prediction)
        }
        onCandidatesChanged?()
    }

    /// Ask for next-word suggestions. `context` should be the latest committed text
    /// (or a short document tail). Requires Full Access for network.
    func requestNextWordPredictions(context: String, hasNetworkAccess: Bool) {
        let trimmed = Self.normalizeContext(context)
        guard !trimmed.isEmpty else {
            predictionStatus = ""
            return
        }
        guard !isComposing else { return }

        lastCommitted = trimmed
        lastPredictionContext = trimmed
        applyLocalPredictions(after: trimmed)
        scheduleLLMPredictions(after: trimmed, hasNetworkAccess: hasNetworkAccess)
    }

    private static func normalizeContext(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        // Prefer last ~24 chars / last short clause for LLM context.
        if t.count <= 24 { return t }
        return String(t.suffix(24))
    }

    private func scheduleLLMPredictions(after text: String, hasNetworkAccess: Bool = true) {
        llmTask?.cancel()
        AppSettings.shared.reloadFromDisk()
        guard AppSettings.shared.canUseLLM else {
            let reason = AppSettings.shared.llmBlockedReason
            predictionStatus = reason.isEmpty ? "LLM未就緒" : reason
            onCandidatesChanged?()
            return
        }
        guard hasNetworkAccess else {
            predictionStatus = "需開啟「完整取用」才能LLM"
            onCandidatesChanged?()
            return
        }

        predictionStatus = "LLM…"
        onCandidatesChanged?()
        let local = candidates.filter { $0.source != .llm }
        let token = text
        llmTask = Task { [weak self] in
            let result = await LLMPredictor.shared.suggestDetailed(after: token, limit: 5)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                // Only apply if still idle and context matches.
                guard !self.isComposing, self.lastPredictionContext == token else { return }
                if result.words.isEmpty {
                    self.predictionStatus = result.errorMessage.map { "LLM失敗：\($0)" } ?? "LLM無結果"
                    self.onCandidatesChanged?()
                    return
                }
                var seen = Set(local.map(\.text))
                var merged = local
                for (i, w) in result.words.enumerated() where !seen.contains(w) {
                    seen.insert(w)
                    merged.append(Candidate(
                        id: "llm-\(i)-\(w)",
                        text: w,
                        reading: "LLM",
                        score: 900 - Double(i),
                        source: .llm
                    ))
                }
                // ponytail: sort by score (local predictions first, then LLM)
                self.candidates = merged.sorted { $0.score > $1.score }
                self.predictionStatus = ""
                self.onCandidatesChanged?()
            }
        }
    }

    func insertPassthroughAndClear(_ text: String) -> String {
        clearComposing()
        predictionStatus = ""
        return text
    }

    func handleSpace() -> String { insertPassthroughAndClear(" ") }
    func handleReturn() -> String { insertPassthroughAndClear("\n") }
    func handleSymbol(_ symbol: String) -> String { insertPassthroughAndClear(symbol) }

    // MARK: - Swift T9 ranking

    private func refreshSwiftCandidates() {
        // Runs on every exit path (including the early-return for empty composing digits) so
        // callers always get the UI to refresh after this call.
        defer { onCandidatesChanged?() }
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
                let toneBonus = toneScore(tones: e.tones, syllableLengths: e.syllableLengths)
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
            let toneBonus = toneScore(tones: phrase.tones, syllableLengths: phrase.syllableLengths)
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
            let toneBonus = toneScore(tones: path.tones, syllableLengths: path.syllableLengths)
            let userBoost = userLexicon.boost(for: path.text, previous: lastCommitted.isEmpty ? nil : lastCommitted)
            // Proportional (not flat) penalty: libchewing single-char weights can be ~10x a real
            // phrase's weight, so a flat penalty is swamped and a chop of two common chars
            // (e.g. 但+試) out-ranks the real phrase (但是). Scale the penalty to the path's own
            // weight so it stays meaningful regardless of the corpus's weight range.
            // ponytail: 0.75 is a tuned constant, not a language model — revisit if mis-ranks show up.
            let segCount = Double(max(0, path.entries.count - 1))
            let segPenalty = Double(path.weight) * segCount * 0.75
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
                        score: Double(first.weight) + toneScore(tones: first.tones, syllableLengths: first.syllableLengths) + userLexicon.boost(for: first.word, previous: lastCommitted.isEmpty ? nil : lastCommitted),
                        source: .exact
                    ),
                    coverage: first.t9.count,
                    fullCoverage: false,
                    orphanTone: false
                ))
            }
        }

        if AppSettings.shared.fuzzyNeighborEffective {
            for m in FuzzyMatcher.fuzzy(digits: digits, lexicon: lexicon, maxDistance: 1, limit: 12) {
                let toneBonus = toneScore(tones: m.entry.tones, syllableLengths: m.entry.syllableLengths) * 0.5
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
        }

        items.sort { $0.candidate.score > $1.candidate.score }
        let sorted = T9SortFilter.sort(items: items, inputDigitsAndTones: inputStream, digitsCount: digits.count)
        candidates = Array(sorted.prefix(candidateLimit))
    }

    /// Matches each typed tone to the syllable it was pressed for, by comparing the digit
    /// count at press time against this candidate's own per-syllable digit boundaries —
    /// NOT by press order. Two syllables can need different tones typed in either order
    /// (e.g. tone pressed right after the first syllable, more digits typed after that for
    /// a second, untoned syllable); assuming the last-pressed tone belongs to the last
    /// syllable silently misattributes it whenever the counts don't line up.
    private func toneScore(tones entryTones: String, syllableLengths: String) -> Double {
        guard !toneMarks.isEmpty else { return 0 }
        let toneChars = Array(entryTones)
        let lengths = syllableLengths.utf8  // one ASCII digit per syllable
        guard toneChars.count == lengths.count else { return 0 }

        var boundaryForDigits: [Int: Character] = [:]
        var boundary = 0
        for (i, len) in lengths.enumerated() {
            boundary += Int(len) - 48  // ASCII '0'
            boundaryForDigits[boundary] = toneChars[i]
        }

        var bonus: Double = 0
        for mark in toneMarks {
            guard let entryTone = boundaryForDigits[mark.digits] else {
                bonus -= 500 // this candidate doesn't have a syllable break where the tone was pressed
                continue
            }
            guard entryTone != "-" else { continue } // neutral/unknown tone: no anchor either way
            bonus += (mark.tone == entryTone) ? 12_000 : -18_000
        }
        return bonus
    }
}
