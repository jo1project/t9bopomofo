// Throwaway perf benchmark — NOT part of the app (run as a temp step in .github/workflows/build-ipa.yml).
// Concatenated onto LexiconEntry.swift, T9KeyMap.swift, SyllableCodec.swift, DictionaryLoader.swift,
// PhraseSegmenter.swift and FuzzyMatcher.swift, compiled with swiftc, run on a macOS runner.
//
// Times the compute that InputEngine.refreshSwiftCandidates() does per keystroke (prefixSpans +
// bestPhrase + nBest + fuzzy) on an already-loaded lexicon, typing digit strings one key at a time.
// Only the public signatures are used, so the same file builds against both the baseline and the
// fixed sources — the workflow runs both and prints them next to each other.
//
// Usage: bench_keystroke <label> <base.yaml> <phrases.yaml>

import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
    FileHandle.standardError.write("usage: bench_keystroke <label> <base.yaml> <phrases.yaml>\n".data(using: .utf8)!)
    exit(1)
}
let label = arguments[1]

let lexicon = DictionaryLoader()
do {
    try lexicon.load(from: [URL(fileURLWithPath: arguments[2]), URL(fileURLWithPath: arguments[3])])
} catch {
    FileHandle.standardError.write("bench_keystroke load failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}

var sink = 0
func keystroke(_ digits: String) {
    for (_, es) in lexicon.prefixSpans(of: digits) { sink &+= es.count }
    sink &+= PhraseSegmenter.bestPhrase(digits: digits, lexicon: lexicon)?.weight ?? 0
    sink &+= PhraseSegmenter.nBest(digits: digits, lexicon: lexicon, limit: 8).count
    sink &+= FuzzyMatcher.fuzzy(digits: digits, lexicon: lexicon, maxDistance: 1, limit: 12).count
}

let sequences = ["139625807", "6398", "3131", "7852049"]  // arbitrary but realistic multi-key inputs
let rounds = 10
var perKey: [Int: [Double]] = [:]  // keys typed so far -> ms samples
for _ in 0..<rounds {
    for seq in sequences {
        for n in 1...seq.count {
            let digits = String(seq.prefix(n))
            let t0 = CFAbsoluteTimeGetCurrent()
            keystroke(digits)
            perKey[n, default: []].append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
        }
    }
}

print("[bench:\(label)] per-keystroke ms by number of digits typed (median / max over \(rounds * sequences.count) samples)")
for n in perKey.keys.sorted() {
    let s = perKey[n]!.sorted()
    print(String(format: "[bench:%@]   %d digits: median %.2fms  max %.2fms", label, n, s[s.count / 2], s.last!))
}
let all = perKey.values.flatMap { $0 }.sorted()
print(String(format: "[bench:%@] overall: median %.2fms  p95 %.2fms  max %.2fms (sink=%d)", label, all[all.count / 2], all[all.count * 95 / 100], all.last!, sink))
