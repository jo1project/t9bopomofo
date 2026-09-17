// Throwaway perf benchmark — NOT part of the app, NOT wired into any product build
// phase. Concatenated (by .github/workflows/bench-lexicon.yml) onto the real
// LexiconEntry.swift, T9KeyMap.swift, SyllableCodec.swift, DictionaryLoader.swift,
// compiled with swiftc, and run on a macOS CI runner.
//
// Purpose: settle, with real numbers instead of another guess, where the
// "~1s before the first keystroke shows anything" time actually goes — YAML text
// parsing, PropertyListDecoder, or DictionaryLoader.rebuildIndex(). Delete this
// file (and the bench-lexicon.yml workflow) once that's answered and any follow-up
// fix is verified, unless it's worth keeping as a standing perf check.
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

    // D: raw text -> [LexiconEntry], no dedup, no index — isolates SyllableCodec-driven
    // text parsing alone (parseDictionaryYAML is `internal`, callable from here since
    // this file is concatenated into the same compilation unit as DictionaryLoader).
    var parsedOnly: [LexiconEntry] = []
    let tD = try time("D: YAML parse only (no dedup/index)") {
        for url in yamlURLs {
            let text = try String(contentsOf: url, encoding: .utf8)
            parsedOnly.append(contentsOf: DictionaryLoader.parseDictionaryYAML(text))
        }
    }
    print("[bench] D produced \(parsedOnly.count) raw rows (pre-dedup)")

    // A: the ORIGINAL runtime path end to end (parse + dedup + rebuildIndex) — what
    // every build before the prebuilt-binary change actually paid on cold launch.
    let yamlLoader = DictionaryLoader()
    let tA = try time("A: full YAML path (parse+dedup+rebuildIndex) — pre-fix baseline") {
        try yamlLoader.load(from: yamlURLs)
    }
    print("[bench] A produced \(yamlLoader.entries.count) deduped entries")

    // Encode a binary snapshot from A's result, exactly like generate_lexicon_main.swift does.
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let binData = try encoder.encode(yamlLoader.entries)
    let binURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bench_lexicon.bin")
    try binData.write(to: binURL)
    print("[bench] binary snapshot: \(binData.count) bytes")

    // C: PropertyListDecoder alone — isolates Codable/plist decode cost, no rebuildIndex.
    let tC = try time("C: binary plist decode only (no rebuildIndex)") {
        let data = try Data(contentsOf: binURL)
        _ = try PropertyListDecoder().decode([LexiconEntry].self, from: data)
    }

    // B: the CURRENTLY SHIPPED runtime path end to end (decode + rebuildIndex).
    let binLoader = DictionaryLoader()
    let tB = try time("B: full binary path (decode+rebuildIndex) — currently shipped") {
        try binLoader.loadBinary(from: binURL)
    }
    print("[bench] B produced \(binLoader.entries.count) entries")

    print("[bench] inferred rebuildIndex cost, binary path (B - C): \(ms(tB - tC))")
    print("[bench] inferred dedup+rebuildIndex cost, YAML path (A - D): \(ms(tA - tD))")
} catch {
    FileHandle.standardError.write("bench_lexicon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
