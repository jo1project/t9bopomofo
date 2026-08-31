import Foundation

final class DictionaryLoader: @unchecked Sendable {
    private(set) var entries: [LexiconEntry] = []
    /// Prefix index: T9 digits → entry indices
    private var prefixBuckets: [String: [Int]] = [:]

    func load(from urls: [URL]) throws {
        var all: [LexiconEntry] = []
        for url in urls {
            let text = try String(contentsOf: url, encoding: .utf8)
            all.append(contentsOf: Self.parseDictionaryYAML(text))
        }
        // Prefer higher weight on duplicates of same word+reading
        var best: [String: LexiconEntry] = [:]
        for e in all {
            let key = e.word + "\t" + e.reading
            if let existing = best[key] {
                if e.weight > existing.weight { best[key] = e }
            } else {
                best[key] = e
            }
        }
        entries = Array(best.values)
        rebuildIndex()
    }

    func loadFromBundle(bundle: Bundle = .main) throws {
        var urls: [URL] = []
        let names = ["taiwan_phrases.dict", "bopomofo_t9.dict"]
        let subdirs: [String?] = ["rime", nil]
        for name in names {
            for sub in subdirs {
                if let url = bundle.url(forResource: name, withExtension: "yaml", subdirectory: sub) {
                    urls.append(url)
                    break
                }
            }
        }
        guard !urls.isEmpty else {
            throw NSError(domain: "T9Bopomofo", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Dictionary YAML not found in bundle",
            ])
        }
        try load(from: urls)
    }

    func candidates(forDigits digits: String, limit: Int = 40) -> [LexiconEntry] {
        guard !digits.isEmpty else { return [] }
        // Exact prefix matches via bucket of first 1–4 keys, then filter.
        let key = String(digits.prefix(min(4, digits.count)))
        let idxs = prefixBuckets[key] ?? entries.indices.filter { entries[$0].t9.hasPrefix(String(digits.prefix(1))) }
        var out: [LexiconEntry] = []
        out.reserveCapacity(limit)
        for i in idxs {
            let e = entries[i]
            if e.t9 == digits || e.t9.hasPrefix(digits) {
                out.append(e)
                if out.count >= limit * 3 { break }
            }
        }
        return Array(out.sorted { $0.weight > $1.weight }.prefix(limit))
    }

    func exact(digits: String) -> [LexiconEntry] {
        entries.filter { $0.t9 == digits }.sorted { $0.weight > $1.weight }
    }

    // MARK: - Parse

    static func parseDictionaryYAML(_ text: String) -> [LexiconEntry] {
        var result: [LexiconEntry] = []
        var pastHeader = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let raw = String(line)
            if raw.trimmingCharacters(in: .whitespaces) == "..." {
                pastHeader = true
                continue
            }
            guard pastHeader else { continue }
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // format: word<TAB>reading[<TAB>weight]
            let cols = raw.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 2 else { continue }
            let word = cols[0]
            let reading = cols[1].trimmingCharacters(in: .whitespaces)
            if reading.isEmpty { continue }
            // Skip non-pinyin-ish codes (english brand readings still ok if encode works)
            let weight: Int
            if cols.count >= 3 {
                weight = parseWeight(cols[2])
            } else {
                weight = 1000
            }
            let (digits, tones) = SyllableCodec.encodeReading(reading)
            guard !digits.isEmpty else { continue }
            result.append(LexiconEntry(word: word, reading: reading, t9: digits, tones: tones, weight: weight))
        }
        return result
    }

    private static func parseWeight(_ s: String) -> Int {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasSuffix("%"), let v = Double(t.dropLast()) {
            return Int(v * 100)
        }
        if let v = Int(t) { return v }
        if let v = Double(t) { return Int(v) }
        return 1000
    }

    private func rebuildIndex() {
        prefixBuckets.removeAll(keepingCapacity: true)
        for (idx, e) in entries.enumerated() {
            let p = String(e.t9.prefix(min(4, e.t9.count)))
            prefixBuckets[p, default: []].append(idx)
            if e.t9.count >= 2 {
                let p2 = String(e.t9.prefix(2))
                if p2 != p { prefixBuckets[p2, default: []].append(idx) }
            }
            let p1 = String(e.t9.prefix(1))
            prefixBuckets[p1, default: []].append(idx)
        }
    }
}
