import Foundation

final class DictionaryLoader: @unchecked Sendable {
    /// Eager path (YAML at build time / dev fallback): full T9 string → entries, weight-descending.
    private var memory: [String: [LexiconEntry]] = [:]
    /// Bundle path: lexicon.bin memory-mapped, nothing decoded until a query hits a bucket.
    private var mapped: MappedLexicon?

    /// All entries of the eager load (the build-time generator reads this).
    var entries: [LexiconEntry] { memory.values.flatMap { $0 } }

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
        memory = Dictionary(grouping: best.values, by: \.t9).mapValues(MappedLexicon.bucketOrder)
    }

    /// Maps a lexicon.bin written by Scripts/generate_lexicon_main.swift. False if missing or invalid.
    func load(mappedURL url: URL) -> Bool {
        mapped = MappedLexicon(url: url)
        return mapped != nil
    }

    /// The old plist shards had to be decoded into ~160k structs before a query could use them
    /// (~150ms per shard on the main thread, again every time iOS relaunched the keyboard — which
    /// big host apps like Line/IG make iOS do often). lexicon.bin is memory-mapped instead: opening
    /// it is instant, and its pages are clean file-backed memory iOS can drop and re-read rather
    /// than counting it against the extension.
    func loadFromBundle(bundle: Bundle = .main) throws {
        if let url = Self.resourceURL(bundle: bundle, name: "lexicon", ext: "bin"), load(mappedURL: url) {
            return
        }

        // Dev/fallback path: no valid lexicon.bin, parse the YAML directly (eager).
        var urls: [URL] = []
        for name in ["taiwan_phrases.dict", "chewing_base.dict"] {
            if let url = Self.resourceURL(bundle: bundle, name: name, ext: "yaml") {
                urls.append(url)
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
        guard !digits.isEmpty else { return [] }
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
        if let mapped { return mapped.lookup(digits, limit: limit) }
        return Array((memory[digits] ?? []).prefix(limit))  // buckets are weight-descending
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

/// lexicon.bin, little-endian, every field a 4-byte word:
///   header   "T9LX", version, keyCount, entryCount
///   keys     keyCount × (t9Off, t9Len, firstEntry, entryCount), sorted by t9 bytes
///   entries  entryCount × (wordOff, wordLen, readingOff, readingLen, tonesOff, tonesLen,
///            sylOff, sylLen, weight as Int32), each key's run weight-descending
///   strings  UTF-8 blob; offsets above are relative to its start
/// Written by `MappedLexicon.encode` at build time (Scripts/generate_lexicon_main.swift).
struct MappedLexicon {
    static let magic: UInt32 = 0x584C_3954  // "T9LX"
    static let version: UInt32 = 1
    private static let headerSize = 16, keySize = 16, entrySize = 36

    private let data: Data
    private let keyCount: Int
    private let entriesStart: Int
    private let stringsStart: Int

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped),
              data.count >= Self.headerSize else { return nil }
        let (magic, version, keys, entries) = data.withUnsafeBytes { p in
            (Self.word(p, 0), Self.word(p, 4), Int(Self.word(p, 8)), Int(Self.word(p, 12)))
        }
        let entriesStart = Self.headerSize + keys * Self.keySize
        let stringsStart = entriesStart + entries * Self.entrySize
        guard magic == Self.magic, version == Self.version, stringsStart <= data.count else { return nil }
        self.data = data
        self.keyCount = keys
        self.entriesStart = entriesStart
        self.stringsStart = stringsStart
    }

    /// Weight-descending; ties by word then reading so the file is deterministic.
    static func bucketOrder(_ entries: [LexiconEntry]) -> [LexiconEntry] {
        entries.sorted {
            if $0.weight != $1.weight { return $0.weight > $1.weight }
            return ($0.word, $0.reading) < ($1.word, $1.reading)
        }
    }

    func lookup(_ digits: String, limit: Int) -> [LexiconEntry] {
        let query = Array(digits.utf8)
        return data.withUnsafeBytes { p in
            var lo = 0, hi = keyCount
            while lo < hi {
                let mid = (lo + hi) / 2
                let k = Self.headerSize + mid * Self.keySize
                let key = string(p, Self.word(p, k), Self.word(p, k + 4))
                if key.elementsEqual(query) {
                    let first = Int(Self.word(p, k + 8))
                    let count = min(Int(Self.word(p, k + 12)), limit)
                    return (first..<first + count).map { entry(p, $0, t9: digits) }
                }
                if key.lexicographicallyPrecedes(query) { lo = mid + 1 } else { hi = mid }
            }
            return []
        }
    }

    private func entry(_ p: UnsafeRawBufferPointer, _ i: Int, t9: String) -> LexiconEntry {
        let e = entriesStart + i * Self.entrySize
        func text(_ field: Int) -> String {
            String(decoding: string(p, Self.word(p, e + field * 8), Self.word(p, e + field * 8 + 4)), as: UTF8.self)
        }
        return LexiconEntry(word: text(0), reading: text(1), t9: t9, tones: text(2), syllableLengths: text(3),
                            weight: Int(Int32(bitPattern: Self.word(p, e + 32))))
    }

    private func string(_ p: UnsafeRawBufferPointer, _ off: UInt32, _ len: UInt32) -> UnsafeRawBufferPointer {
        let start = stringsStart + Int(off)
        return UnsafeRawBufferPointer(rebasing: p[start..<start + Int(len)])
    }

    private static func word(_ p: UnsafeRawBufferPointer, _ off: Int) -> UInt32 {
        UInt32(littleEndian: p.loadUnaligned(fromByteOffset: off, as: UInt32.self))
    }

    /// Build time only: `buckets` maps each full T9 string to its entries.
    static func encode(_ buckets: [String: [LexiconEntry]]) -> Data {
        let keys = buckets.keys.sorted { Array($0.utf8).lexicographicallyPrecedes(Array($1.utf8)) }
        var keyTable = Data(), entryTable = Data(), strings = Data()
        var interned: [String: UInt32] = [:]
        func put(_ v: UInt32, _ out: inout Data) {
            withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) }
        }
        func putString(_ s: String, _ out: inout Data) {
            let off: UInt32
            if let o = interned[s] {
                off = o
            } else {
                off = UInt32(strings.count)
                strings.append(contentsOf: Array(s.utf8))
                interned[s] = off
            }
            put(off, &out)
            put(UInt32(s.utf8.count), &out)
        }
        var entryCount = 0
        for key in keys {
            let bucket = bucketOrder(buckets[key]!)
            putString(key, &keyTable)
            put(UInt32(entryCount), &keyTable)
            put(UInt32(bucket.count), &keyTable)
            for e in bucket {
                putString(e.word, &entryTable)
                putString(e.reading, &entryTable)
                putString(e.tones, &entryTable)
                putString(e.syllableLengths, &entryTable)
                put(UInt32(bitPattern: Int32(e.weight)), &entryTable)
            }
            entryCount += bucket.count
        }
        var out = Data()
        put(magic, &out)
        put(version, &out)
        put(UInt32(keys.count), &out)
        put(UInt32(entryCount), &out)
        return out + keyTable + entryTable + strings
    }
}
