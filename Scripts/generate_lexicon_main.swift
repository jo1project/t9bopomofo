// Build-time lexicon generator.
//
// NOT compiled into the app — the Keyboard target's prebuild script (see project.yml)
// concatenates this file onto the END of LexiconEntry.swift, T9KeyMap.swift,
// SyllableCodec.swift and DictionaryLoader.swift, then compiles that single file with
// `swiftc`. Reusing those files verbatim (not copies) means this generator parses the
// dictionary exactly the way the extension would at runtime, so the file it produces
// can never drift from DictionaryLoader's own YAML parsing.
//
// Writes one memory-mapped lexicon.bin (format: MappedLexicon in DictionaryLoader.swift), so
// the keyboard opens the dictionary without decoding anything — see
// DictionaryLoader.loadFromBundle for why. Then reads it back through the runtime reader and
// fails the build if any T9 bucket differs from the YAML parse.
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
    let buckets = Dictionary(grouping: loader.entries, by: \.t9)

    let outURL = outDir.appendingPathComponent("lexicon.bin")
    try MappedLexicon.encode(buckets).write(to: outURL, options: .atomic)

    // Self-check: every bucket must read back identical, in weight order, through the runtime path.
    let check = DictionaryLoader()
    guard check.load(mappedURL: outURL) else { throw NSError(domain: "generate_lexicon", code: 2) }
    for (t9, bucket) in buckets where check.exact(digits: t9) != MappedLexicon.bucketOrder(bucket) {
        throw NSError(domain: "generate_lexicon", code: 3, userInfo: [NSLocalizedDescriptionKey: "bucket \(t9) differs"])
    }

    print("generate_lexicon: wrote \(loader.entries.count) entries, \(buckets.count) keys -> \(outURL.path)")
} catch {
    FileHandle.standardError.write("generate_lexicon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
