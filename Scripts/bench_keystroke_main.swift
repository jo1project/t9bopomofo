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
let stepNames = ["prefixSpans", "bestPhrase", "nBest", "fuzzy"]
var spanEntries = 0  // entries prefixSpans returned on the last keystroke = how many candidates InputEngine builds+scores

func keystroke(_ digits: String) -> [Double] {
    var t: [Double] = []
    var t0 = CFAbsoluteTimeGetCurrent()
    func lap() { let n = CFAbsoluteTimeGetCurrent(); t.append((n - t0) * 1000); t0 = n }
    var count = 0
    for (_, es) in lexicon.prefixSpans(of: digits) { count += es.count }
    spanEntries = count
    sink &+= count
    lap()
    sink &+= PhraseSegmenter.bestPhrase(digits: digits, lexicon: lexicon)?.weight ?? 0
    lap()
    sink &+= PhraseSegmenter.nBest(digits: digits, lexicon: lexicon, limit: 8).count
    lap()
    sink &+= FuzzyMatcher.fuzzy(digits: digits, lexicon: lexicon, maxDistance: 1, limit: 12).count
    lap()
    return t
}

let sequences = ["139625807", "6398", "3131", "7852049"]  // arbitrary but realistic multi-key inputs
let rounds = 10
var perKey: [Int: [[Double]]] = [:]  // keys typed so far -> per-step ms samples
var entryCounts: [Int: [Int]] = [:]
for _ in 0..<rounds {
    for seq in sequences {
        for n in 1...seq.count {
            let digits = String(seq.prefix(n))
            perKey[n, default: []].append(keystroke(digits))
            entryCounts[n, default: []].append(spanEntries)
        }
    }
}

func med(_ xs: [Double]) -> Double { let s = xs.sorted(); return s[s.count / 2] }
print("[bench:\(label)] per-keystroke ms by number of digits typed, median over \(rounds * sequences.count) samples: total = \(stepNames.joined(separator: " + "))")
var totals: [Double] = []
for n in perKey.keys.sorted() {
    let samples = perKey[n]!
    let totalsN = samples.map { $0.reduce(0, +) }
    totals.append(contentsOf: totalsN)
    let steps = (0..<stepNames.count).map { i in String(format: "%.2f", med(samples.map { $0[i] })) }
    print(String(format: "[bench:%@]   %d digits: total %.2fms max %.2fms = %@  | prefixSpans entries (median) %d",
                 label, n, med(totalsN), totalsN.max()!, steps.joined(separator: " + "), entryCounts[n]!.sorted()[entryCounts[n]!.count / 2]))
}
let all = totals.sorted()
print(String(format: "[bench:%@] overall: median %.2fms  p95 %.2fms  max %.2fms (sink=%d)", label, all[all.count / 2], all[all.count * 95 / 100], all.last!, sink))
