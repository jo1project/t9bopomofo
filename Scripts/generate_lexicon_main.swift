// Build-time lexicon generator.
//
// NOT compiled into the app — the Keyboard target's prebuild script (see project.yml)
// concatenates this file onto the END of LexiconEntry.swift, T9KeyMap.swift,
// SyllableCodec.swift and DictionaryLoader.swift, then compiles that single file with
// `swiftc`. Reusing those files verbatim (not copies) means this generator parses the
// dictionary exactly the way the extension would at runtime, so the shards it produces
// can never drift from DictionaryLoader's own YAML parsing.
//
// Shards entries by T9 first digit (DictionaryLoader.shardKeys: 0-9, v) into separate
// binary-plist files, so DictionaryLoader can lazily decode only the shard(s) a query
// actually touches instead of materializing all ~160k entries before showing a single
// candidate — see DictionaryLoader.ensureShardLoaded for why (measured: decoding the
// full set costs 1.5-2s regardless of source format, dominated by building ~160k small
// structs, not by rebuildIndex()).
//
// Usage: generate_lexicon <base.dict.yaml> <phrases.dict.yaml> <out dir>

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(
        "usage: generate_lexicon <base.yaml> <phrases.yaml> <out dir>\n".data(using: .utf8)!
    )
    exit(1)
}

do {
    let sourceURLs = [URL(fileURLWithPath: arguments[1]), URL(fileURLWithPath: arguments[2])]
    let outDir = URL(fileURLWithPath: arguments[3], isDirectory: true)

    let loader = DictionaryLoader()
    try loader.load(from: sourceURLs)

    var shards: [Character: [LexiconEntry]] = [:]
    for e in loader.entries {
        guard let first = e.t9.first else { continue }
        shards[first, default: []].append(e)
    }

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary

    var total = 0
    for key in DictionaryLoader.shardKeys {
        let shard = shards[key] ?? []
        let data = try encoder.encode(shard)
        let outURL = outDir.appendingPathComponent("lexicon-\(key).bin")
        try data.write(to: outURL, options: .atomic)
        print("generate_lexicon: shard '\(key)' — \(shard.count) entries -> \(outURL.lastPathComponent)")
        total += shard.count
    }

    print("generate_lexicon: wrote \(total) entries across \(DictionaryLoader.shardKeys.count) shards -> \(outDir.path)")
} catch {
    FileHandle.standardError.write("generate_lexicon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
