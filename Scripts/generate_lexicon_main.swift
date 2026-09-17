// Build-time lexicon generator.
//
// NOT compiled into the app — the Keyboard target's prebuild script (see project.yml)
// concatenates this file onto the END of LexiconEntry.swift, T9KeyMap.swift,
// SyllableCodec.swift and DictionaryLoader.swift, then compiles that single file with
// `swiftc`. Reusing those files verbatim (not copies) means this generator parses the
// dictionary exactly the way the extension would at runtime, so the binary it produces
// can never drift from DictionaryLoader's own YAML parsing.
//
// Usage: generate_lexicon <base.dict.yaml> <phrases.dict.yaml> <out lexicon.bin>

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write(
        "usage: generate_lexicon <base.yaml> <phrases.yaml> <out.bin>\n".data(using: .utf8)!
    )
    exit(1)
}

do {
    let sourceURLs = [URL(fileURLWithPath: arguments[1]), URL(fileURLWithPath: arguments[2])]
    let outputURL = URL(fileURLWithPath: arguments[3])

    let loader = DictionaryLoader()
    try loader.load(from: sourceURLs)

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let data = try encoder.encode(loader.entries)
    try data.write(to: outputURL, options: .atomic)

    print("generate_lexicon: wrote \(loader.entries.count) entries -> \(outputURL.path)")
} catch {
    FileHandle.standardError.write("generate_lexicon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
