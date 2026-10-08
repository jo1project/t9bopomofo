import Foundation

final class DictionaryLoader: @unchecked Sendable {
    /// One T9 first-digit's entries, weight-descending, plus full T9 string → indices for O(1)
    /// exact() lookups. Self-contained so a shard decoded off the main thread is merged in with
    /// a single assignment.
    private struct Shard {
        let entries: [LexiconEntry]
        let index: [String: [Int]]

        init(_ entries: [LexiconEntry]) {
            // Weight-descending order = every index bucket is already sorted by weight (see exact()).
            self.entries = entries.sorted { $0.weight > $1.weight }
            var index: [String: [Int]] = [:]
            for (i, e) in self.entries.enumerated() {
                index[e.t9, default: []].append(i)
            }
            self.index = index
        }
    }

    /// Main thread only; the background preload hands shards back via the main queue.
    private var shards: [Character: Shard] = [:]

    /// All loaded entries (build scripts read this after the eager `load(from:)`).
    var entries: [LexiconEntry] { shards.values.flatMap(\.entries) }

    /// T9 keys, one shard per first digit — matches Scripts/generate_lexicon_main.swift's
    /// sharding and T9KeyMap's key alphabet.
    static let shardKeys: [Character] = Array("0123456789v")

    /// Set once a sharded bundle is found; nil means we're in the eager YAML/dev path below.
    private var shardBundle: Bundle?

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
        shards = Dictionary(grouping: best.values) { $0.t9.first ?? " " }.mapValues(Shard.init)
    }

    /// Build-time (Scripts/generate_lexicon_main.swift) shards the dictionary into one
    /// binary-plist file per T9 first-digit (lexicon-0.bin … lexicon-9.bin, lexicon-v.bin).
    /// At runtime we don't decode ANY of them up front — decoding all ~160k entries turned
    /// out to cost 1.5-2s regardless of source format (YAML text or Codable/plist), and that
    /// was the real cause of the "first keystroke takes ~1s" complaint, not rebuildIndex().
    /// Instead we remember the bundle and decode shards one at a time on a background queue
    /// (`preloadShards`). A query that reaches a shard before the preload does decodes it
    /// synchronously (`ensureShardLoaded`), which was the "random" lag: ~150ms on the first
    /// word starting with each key, again every time iOS relaunched the keyboard.
    /// ponytail: preloading holds the whole lexicon in memory (normal typing touched most shards
    /// anyway); if the extension hits its memory limit, preload only the common first keys.
    func loadFromBundle(bundle: Bundle = .main) throws {
        if Self.resourceURL(bundle: bundle, name: "lexicon-0", ext: "bin") != nil {
            shardBundle = bundle
            preloadShards(bundle: bundle)
            return
        }

        // Dev/fallback path: no sharded bundle found, parse the YAML directly (eager).
        var urls: [URL] = []
        let names = ["taiwan_phrases.dict", "chewing_base.dict"]
        let subdirs: [String?] = ["chewing", nil]
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

    private static func resourceURL(bundle: Bundle, name: String, ext: String) -> URL? {
        let subdirs: [String?] = ["chewing", nil]
        for sub in subdirs {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
                return url
            }
        }
        return nil
    }

    private static func decodeShard(_ key: Character, bundle: Bundle) -> Shard {
        guard let url = resourceURL(bundle: bundle, name: "lexicon-\(key)", ext: "bin"),
              let data = try? Data(contentsOf: url),
              let entries = try? PropertyListDecoder().decode([LexiconEntry].self, from: data)
        else { return Shard([]) }  // empty, so a missing shard isn't retried every keystroke
        return Shard(entries)
    }

    private func preloadShards(bundle: Bundle) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for key in Self.shardKeys {
                let shard = Self.decodeShard(key, bundle: bundle)
                DispatchQueue.main.async {
                    guard let self, self.shards[key] == nil else { return }
                    self.shards[key] = shard
                }
            }
        }
    }

    /// Decodes the shard `key` belongs to now if the background preload hasn't delivered it yet.
    /// No-op in the eager (non-sharded) path, where everything is already loaded.
    private func ensureShardLoaded(_ key: Character) {
        guard let bundle = shardBundle, shards[key] == nil else { return }
        syncDecodes += 1
        shards[key] = Self.decodeShard(key, bundle: bundle)
    }

    /// Shards decoded on the main thread because the preload hadn't reached them; shown by the
    /// keyboard's timing overlay.
    private(set) var syncDecodes = 0

    /// All lexicon hits whose T9 exactly equals a prefix of `digits` (Rime partial spans).
    ///
    /// Does NOT truncate per-span hits: many zhuyin symbols share a T9 key (e.g. ㄔㄘㄣㄧ
    /// all on key 6), so a single digit can have hundreds of same-digit, different-tone
    /// homophones. Truncating here by raw weight (tone-agnostic) before the caller applies
    /// tone scoring silently drops the character the user actually wants whenever it isn't
    /// among the handful of highest raw-frequency homophones — which also makes tone
    /// selection look like it does nothing, since the correct tone's candidate was already
    /// cut. The real cutoff (`candidateLimit`) is applied later, after tone scoring.
    func prefixSpans(of digits: String, maxSpan: Int = 12) -> [(span: String, entries: [LexiconEntry])] {
        guard let first = digits.first else { return [] }
        ensureShardLoaded(first)
        var result: [(String, [LexiconEntry])] = []
        let upper = min(maxSpan, digits.count)
        for len in 1...upper {
            let span = String(digits.prefix(len))
            let hits = exact(digits: span)
            if !hits.isEmpty {
                result.append((span, hits))
            }
        }
        return result
    }

    /// `limit`: only the top hits by weight, without copying the whole bucket first.
    func exact(digits: String, limit: Int = .max) -> [LexiconEntry] {
        guard let first = digits.first else { return [] }
        ensureShardLoaded(first)
        guard let shard = shards[first], let idxs = shard.index[digits] else { return [] }
        return idxs.prefix(limit).map { shard.entries[$0] }  // buckets are built weight-descending
    }

    // MARK: - Parse

    static func parseDictionaryYAML(_ text: String) -> [LexiconEntry] {
        var result: [LexiconEntry] = []
        result.reserveCapacity(100000)
        var pastHeader = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let raw = String(line)
            if !pastHeader {
                if raw.trimmingCharacters(in: .whitespaces) == "..." {
                    pastHeader = true
                }
                continue
            }
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
            let (digits, tones, syllableLengths) = SyllableCodec.encodeReading(reading)
            guard !digits.isEmpty else { continue }
            result.append(LexiconEntry(word: word, reading: reading, t9: digits, tones: tones, syllableLengths: syllableLengths, weight: weight))
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
}
