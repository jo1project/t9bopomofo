// Throwaway perf benchmark — NOT part of the app, NOT wired into any product build
// phase (currently invoked as a temp step in .github/workflows/build-ipa.yml). Concatenated
// onto the real LexiconEntry.swift, T9KeyMap.swift, SyllableCodec.swift, DictionaryLoader.swift,
// compiled with swiftc, and run on a macOS CI runner.
//
// Round 1 (monolithic YAML vs monolithic binary-plist load) showed PropertyListDecoder
// decoding all ~160k entries was actually SLOWER than the original hand-rolled YAML parser
// (1827ms vs 1085ms decode-only; 2047ms vs 1569ms end to end) — rebuildIndex() was never the
// bottleneck. This round measures the follow-up fix: sharding by T9 first digit
// (DictionaryLoader.shardKeys) so a cold keystroke only ever decodes ONE shard
// (DictionaryLoader.ensureShardLoaded), not all ~160k entries.
//
// Usage: bench_lexicon <base.yaml> <phrases.yaml>

import Foundation

func ms(_ seconds: Double) -> String { String(format: "%.1fms", seconds * 1000) }

@discardableResult
func time(_ label: String, _ body: () throws -> Void) rethrows -> Double {
    let start = CFAbsoluteTimeGetCurrent()
    try body()
    let elapsed = CFAbsoluteTimeGetCurrent() - start
    print("[bench] \(label): \(ms(elapsed))")
    return elapsed
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write("usage: bench_lexicon <base.yaml> <phrases.yaml>\n".data(using: .utf8)!)
    exit(1)
}

do {
    let yamlURLs = [URL(fileURLWithPath: arguments[1]), URL(fileURLWithPath: arguments[2])]

    // D / A: reference baseline from round 1 — the original eager YAML path.
    var parsedOnly: [LexiconEntry] = []
    let tD = try time("D: YAML parse only (no dedup/index)") {
        for url in yamlURLs {
            let text = try String(contentsOf: url, encoding: .utf8)
            parsedOnly.append(contentsOf: DictionaryLoader.parseDictionaryYAML(text))
        }
    }
    print("[bench] D produced \(parsedOnly.count) raw rows (pre-dedup)")

    let yamlLoader = DictionaryLoader()
    let tA = try time("A: full YAML path (parse+dedup+rebuildIndex) — pre-fix baseline") {
        try yamlLoader.load(from: yamlURLs)
    }
    print("[bench] A produced \(yamlLoader.entries.count) deduped entries")
    print("[bench] inferred dedup+rebuildIndex cost, YAML path (A - D): \(ms(tA - tD))")

    // Shard exactly like Scripts/generate_lexicon_main.swift, then time decoding EACH
    // shard alone — this is what a real cold keystroke pays under the lazy design.
    var shards: [Character: [LexiconEntry]] = [:]
    for e in yamlLoader.entries {
        guard let first = e.t9.first else { continue }
        shards[first, default: []].append(e)
    }

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())

    var shardTimes: [(key: Character, count: Int, seconds: Double)] = []
    for key in DictionaryLoader.shardKeys {
        let shard = shards[key] ?? []
        let data = try encoder.encode(shard)
        let url = tmpDir.appendingPathComponent("bench_shard_\(key).bin")
        try data.write(to: url)
        let t = try time("shard '\(key)' decode only (\(shard.count) entries, \(data.count) bytes)") {
            let raw = try Data(contentsOf: url)
            _ = try PropertyListDecoder().decode([LexiconEntry].self, from: raw)
        }
        shardTimes.append((key, shard.count, t))
    }

    if let worst = shardTimes.max(by: { $0.seconds < $1.seconds }) {
        print("[bench] worst-case single shard: '\(worst.key)' (\(worst.count) entries): \(ms(worst.seconds))")
    }
    let sumSeconds = shardTimes.reduce(0.0) { $0 + $1.seconds }
    print("[bench] sum of all \(shardTimes.count) shard decodes (never paid in one shot; for sanity only): \(ms(sumSeconds))")
} catch {
    FileHandle.standardError.write("bench_lexicon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
