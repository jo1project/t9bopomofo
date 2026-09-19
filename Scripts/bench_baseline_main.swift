// Throwaway perf benchmark — NOT part of the app (run by .github/workflows/bench.yml on a macOS runner).
// Concatenated onto LexiconEntry.swift, T9KeyMap.swift, SyllableCodec.swift, DictionaryLoader.swift and
// UserLexicon.swift, compiled with swiftc. Measures the claims from the optimization review before any
// fix is written:
//   1. AppSettings getter cost per keystroke (replica of reloadFromDiskIfNeeded vs an mtime check)
//   2. UserLexicon commit / predictions / export cost as the dictionaries grow
//   3. DictionaryLoader load time + memory, prefixBuckets cost, syllableLengths cost
//
// Usage: bench_baseline <base.yaml> <phrases.yaml>

import Foundation

// Stub: UserLexicon only reads AppSettings.shared.iCloudAutoBackup. The real AppSettings needs an App Group
// container (nil on CI), so its I/O cost is measured by the replica in section 1 instead.
final class AppSettings: @unchecked Sendable {
    static let shared = AppSettings()
    var iCloudAutoBackup = false
}

func timeMs(_ body: () -> Void) -> Double {
    let t0 = CFAbsoluteTimeGetCurrent()
    body()
    return (CFAbsoluteTimeGetCurrent() - t0) * 1000
}

func stats(_ xs: [Double]) -> String {
    let s = xs.sorted()
    return String(format: "median %.4fms  p95 %.4fms  max %.4fms", s[s.count / 2], s[s.count * 95 / 100], s.last!)
}

func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
}

func log(_ s: String) { print("[bench:baseline] \(s)") }

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: bench_baseline <base.yaml> <phrases.yaml>\n".data(using: .utf8)!)
    exit(1)
}

// MARK: - 1. AppSettings getter I/O

struct Payload: Codable {
    var llmEnabled: Bool, llmBaseURL: String, llmAPIKey: String, llmModel: String
    var iCloudAutoBackup: Bool, isSponsored: Bool, fuzzyNeighborEnabled: Bool
    var hapticsEnabled: Bool, soundsEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case llmEnabled, llmBaseURL, llmAPIKey, llmModel, iCloudAutoBackup
        case isSponsored, fuzzyNeighborEnabled, hapticsEnabled, soundsEnabled
    }

    init(llmEnabled: Bool, llmBaseURL: String, llmAPIKey: String, llmModel: String, iCloudAutoBackup: Bool,
         isSponsored: Bool, fuzzyNeighborEnabled: Bool, hapticsEnabled: Bool, soundsEnabled: Bool) {
        self.llmEnabled = llmEnabled; self.llmBaseURL = llmBaseURL; self.llmAPIKey = llmAPIKey
        self.llmModel = llmModel; self.iCloudAutoBackup = iCloudAutoBackup; self.isSponsored = isSponsored
        self.fuzzyNeighborEnabled = fuzzyNeighborEnabled; self.hapticsEnabled = hapticsEnabled
        self.soundsEnabled = soundsEnabled
    }

    // Same decodeIfPresent-per-field shape as AppSettings.FilePayload.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llmEnabled = try c.decodeIfPresent(Bool.self, forKey: .llmEnabled) ?? false
        llmBaseURL = try c.decodeIfPresent(String.self, forKey: .llmBaseURL) ?? ""
        llmAPIKey = try c.decodeIfPresent(String.self, forKey: .llmAPIKey) ?? ""
        llmModel = try c.decodeIfPresent(String.self, forKey: .llmModel) ?? ""
        iCloudAutoBackup = try c.decodeIfPresent(Bool.self, forKey: .iCloudAutoBackup) ?? false
        isSponsored = try c.decodeIfPresent(Bool.self, forKey: .isSponsored) ?? false
        fuzzyNeighborEnabled = try c.decodeIfPresent(Bool.self, forKey: .fuzzyNeighborEnabled) ?? true
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        soundsEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundsEnabled) ?? true
    }
}

do {
    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bench_settings.json")
    let sample = Payload(llmEnabled: true, llmBaseURL: "https://api.openai.com/v1", llmAPIKey: "•keychain•",
                         llmModel: "gpt-4o-mini", iCloudAutoBackup: true, isSponsored: true,
                         fuzzyNeighborEnabled: true, hapticsEnabled: true, soundsEnabled: true)
    try JSONEncoder().encode(sample).write(to: url)

    let lock = NSLock()
    var cache: Payload?
    // Replica of AppSettings.reloadFromDiskIfNeeded()/readFileUnlocked(): runs on EVERY getter call.
    func readUnlocked() {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let p = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        cache = p
    }
    func reloadBaseline() {
        lock.lock(); defer { lock.unlock() }
        readUnlocked()
    }
    // Candidate fix: stat() and only re-read when the mtime moved.
    var lastMtime = timespec()
    func reloadIfChanged() {
        lock.lock(); defer { lock.unlock() }
        var st = stat()
        guard stat(url.path, &st) == 0 else { return }
        if st.st_mtimespec.tv_sec == lastMtime.tv_sec && st.st_mtimespec.tv_nsec == lastMtime.tv_nsec, cache != nil { return }
        lastMtime = st.st_mtimespec
        readUnlocked()
    }

    // One keystroke = haptics + sounds + fuzzyNeighborEffective (isSponsored + fuzzyNeighborEnabled) = 4 getter calls.
    let calls = 4
    for (label, reload) in [("baseline (read+decode every getter)", reloadBaseline),
                            ("mtime check (candidate fix)", reloadIfChanged)] as [(String, () -> Void)] {
        for _ in 0..<200 { for _ in 0..<calls { reload() } }  // warm up
        var samples: [Double] = []
        for _ in 0..<3000 { samples.append(timeMs { for _ in 0..<calls { reload() } }) }
        log("1. AppSettings, per keystroke (\(calls) getters), \(label): \(stats(samples))")
    }
    log("1. payload size: \((try? Data(contentsOf: url).count) ?? -1) bytes")
} catch {
    log("1. AppSettings section failed: \(error)")
}

// MARK: - 2. UserLexicon growth

func randomWord(_ rng: inout UInt64, chars: Int) -> String {
    var s = ""
    for _ in 0..<chars {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        s.unicodeScalars.append(Unicode.Scalar(UInt32(0x4E00) + UInt32((rng >> 33) % 20_000))!)
    }
    return s
}

for n in [500, 2_000, 10_000, 50_000] {
    var rng: UInt64 = 42
    var words: [String] = []
    var freq: [String: Int] = [:]
    var bigram: [String: Int] = [:]
    for _ in 0..<n {
        let w = randomWord(&rng, chars: 2)
        words.append(w)
        freq[w] = Int(rng >> 60) + 1
    }
    for i in 1..<n { bigram[words[i - 1] + "\u{1f}" + words[i]] = Int(rng >> 61) + 1 }
    // Give the last word a realistic handful of followers so predictions() has work to rank.
    for i in 0..<5 { bigram[words[n - 1] + "\u{1f}" + words[i]] = 3 + i }

    let suite = "bench.userlexicon.\(UUID().uuidString)"
    let lex = UserLexicon(suiteName: suite)
    let snapData = try! JSONEncoder().encode(UserLexicon.Snapshot(freq: freq, bigram: bigram, recent: [], exportedAt: Date()))
    _ = try! lex.importJSON(snapData, merge: false)

    var commit: [Double] = [], predict: [Double] = [], export: [Double] = []
    for i in 0..<30 { commit.append(timeMs { lex.recordCommit(words[i], previous: words[i + 1]) }) }
    for _ in 0..<30 { predict.append(timeMs { _ = lex.predictions(after: words[n - 1]) }) }
    var exportBytes = 0
    for _ in 0..<10 { export.append(timeMs { exportBytes = (try? lex.exportJSON().count) ?? 0 }) }
    log("2. UserLexicon freq=\(n) bigram≈\(n): recordCommit \(stats(commit))")
    log("2. UserLexicon freq=\(n) bigram≈\(n): predictions(after:) \(stats(predict))")
    log("2. UserLexicon freq=\(n) bigram≈\(n): exportJSON \(stats(export)), \(exportBytes / 1024) KB (iCloud KVS limit ≈ 1024 KB)")
    UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
}

// MARK: - 3. Lexicon load, prefixBuckets, syllableLengths

do {
    let lexicon = DictionaryLoader()
    let m0 = footprintMB()
    let loadMs = timeMs { try? lexicon.load(from: [URL(fileURLWithPath: args[1]), URL(fileURLWithPath: args[2])]) }
    let m1 = footprintMB()
    let entries = lexicon.entries
    log("3. DictionaryLoader.load (YAML, eager, all shards): \(String(format: "%.0fms", loadMs)), \(entries.count) entries, footprint +\(String(format: "%.1f", m1 - m0))MB")

    // Exact replica of DictionaryLoader.indexEntry's prefixBuckets half, over a slice of entries.
    func buildPrefixBuckets(_ es: [LexiconEntry]) -> [String: [Int]] {
        var b: [String: [Int]] = [:]
        for (idx, e) in es.enumerated() {
            let p4 = String(e.t9.prefix(min(4, e.t9.count)))
            b[p4, default: []].append(idx)
            if e.t9.count >= 2 {
                let p2 = String(e.t9.prefix(2))
                if p2 != p4 { b[p2, default: []].append(idx) }
            }
            b[String(e.t9.prefix(1)), default: []].append(idx)
        }
        return b
    }

    var byFirst: [Character: [LexiconEntry]] = [:]
    for e in entries { if let f = e.t9.first { byFirst[f, default: []].append(e) } }
    if let worst = byFirst.max(by: { $0.value.count < $1.value.count }) {
        let a = footprintMB()
        var b: [String: [Int]] = [:]
        let t = timeMs { b = buildPrefixBuckets(worst.value) }
        let c = footprintMB()
        log("3. prefixBuckets replica, worst single shard '\(worst.key)' (\(worst.value.count) entries): \(String(format: "%.1fms", t)), footprint +\(String(format: "%.1f", c - a))MB (\(b.count) keys)")
        b = [:]
    }
    do {
        let a = footprintMB()
        var b: [String: [Int]] = [:]
        let t = timeMs { b = buildPrefixBuckets(entries) }
        let c = footprintMB()
        log("3. prefixBuckets replica, all \(entries.count) entries: \(String(format: "%.1fms", t)), footprint +\(String(format: "%.1f", c - a))MB (\(b.count) keys)")
        b = [:]
    }

    // syllableLengths: N separate [Int] heap buffers vs an inline small String.
    do {
        let a = footprintMB()
        var arrays: [[Int]] = []
        let t = timeMs { arrays = entries.map { $0.syllableLengths.utf8.map { Int($0) - 48 } } }  // replica of the old [Int] field
        let c = footprintMB()
        log("3. syllableLengths, old [Int] replica x\(arrays.count): \(String(format: "%.1fms", t)), footprint +\(String(format: "%.1f", c - a))MB")
        arrays = []
        let d = footprintMB()
        var strs: [String] = []
        let t2 = timeMs { strs = entries.map { $0.syllableLengths } }  // the current String field
        let e = footprintMB()
        log("3. syllableLengths, current String x\(strs.count): \(String(format: "%.1fms", t2)), footprint +\(String(format: "%.1f", e - d))MB")
        strs = []
    }
    withExtendedLifetime(lexicon) {}
}
