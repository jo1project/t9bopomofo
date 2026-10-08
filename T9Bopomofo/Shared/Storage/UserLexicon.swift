import Foundation

/// Local learning + simple bigram context (App Group / UserDefaults).
final class UserLexicon: @unchecked Sendable {
    private let defaults: UserDefaults
    private let freqKey = "user_word_freq_v1"
    private let bigramKey = "user_bigram_v1"
    private let recentKey = "user_recent_commits_v1"
    private let iCloudKey = "t9_lexicon_snapshot_v1"

    private var freq: [String: Int]
    private var bigram: [String: Int]
    private var recent: [String]
    /// `bigram` regrouped as previous → next word → count. boost() runs for every candidate on
    /// every keystroke and predictions() several times per commit; with the flat "prev\u{1f}word"
    /// keys they concatenated a key per call and scanned all 5k+ bigrams, growing with use.
    private var next: [String: [String: Int]] = [:]

    struct Snapshot: Codable, Equatable {
        var freq: [String: Int]
        var bigram: [String: Int]
        var recent: [String]
        var exportedAt: Date
    }

    init(suiteName: String = "group.com.jo1project.t9bopomofo") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        freq = defaults.dictionary(forKey: freqKey) as? [String: Int] ?? [:]
        bigram = defaults.dictionary(forKey: bigramKey) as? [String: Int] ?? [:]
        recent = defaults.stringArray(forKey: recentKey) ?? []
        rebuildNext()
        // Pull iCloud copy if local empty and auto-backup on
        if freq.isEmpty, AppSettings.shared.iCloudAutoBackup {
            _ = restoreFromiCloud(merge: false)
        }
    }

    func recordCommit(_ word: String, previous: String?) {
        freq[word, default: 0] += 1
        if let previous, !previous.isEmpty {
            let key = previous + "\u{1f}" + word
            bigram[key, default: 0] += 1
            next[previous, default: [:]][word, default: 0] += 1
        }
        recent.append(word)
        if recent.count > 64 { recent.removeFirst(recent.count - 64) }
        Self.prune(&freq, max: Self.maxFreq)
        if Self.prune(&bigram, max: Self.maxBigram) { rebuildNext() }
        scheduleFlush()
    }

    private func rebuildNext() {
        next = [:]
        for (key, count) in bigram {
            guard let sep = key.firstIndex(of: "\u{1f}") else { continue }
            next[String(key[..<sep]), default: [:]][String(key[key.index(after: sep)...])] = count
        }
    }

    // Measured (Scripts/bench_baseline_main.swift): a commit rewrote both whole dictionaries into
    // UserDefaults, 4ms at 2k entries, 47ms at 10k, 370ms at 50k; the iCloud snapshot passed its
    // ~1MB KVS limit around 30k entries. Bounded size + one write after typing goes idle fixes both.
    private static let maxFreq = 3_000
    private static let maxBigram = 5_000
    private var flushWork: DispatchWorkItem?

    /// Keeps the highest-count entries. Only sorts once 25% over `max`, so a full dictionary
    /// doesn't re-sort on every commit.
    /// ponytail: least-frequent eviction, ties arbitrary — a brand-new word (count 1) can be evicted
    /// before its second use; add a recency tiebreak if that shows up in practice.
    /// Returns true if it pruned.
    @discardableResult
    private static func prune(_ d: inout [String: Int], max: Int) -> Bool {
        guard d.count > max + max / 4 else { return false }
        d = Dictionary(uniqueKeysWithValues: d.sorted { $0.value > $1.value }.prefix(max).map { ($0.key, $0.value) })
        return true
    }

    /// Serial, so a background flush and a later synchronous one land in order.
    private static let io = DispatchQueue(label: "t9.userlexicon.io", qos: .utility)

    private func scheduleFlush() {
        flushWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.write(background: true) }
        flushWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    /// Writes pending commits now. Call when the keyboard goes away: a suspended extension
    /// may never run the 2s timer.
    func flush() { write(background: false) }

    /// The idle flush rewrote both dictionaries plus the iCloud JSON on the main thread (~40ms
    /// once full), stalling the first key typed after a pause; it now runs on `io`.
    private func write(background: Bool) {
        guard let work = flushWork else { return }
        work.cancel()
        flushWork = nil
        let snap = makeSnapshot()
        let backup = AppSettings.shared.iCloudAutoBackup
        let job = { [defaults = self.defaults, freqKey = self.freqKey, bigramKey = self.bigramKey,
                     recentKey = self.recentKey, iCloudKey = self.iCloudKey] in
            defaults.set(snap.freq, forKey: freqKey)
            defaults.set(snap.bigram, forKey: bigramKey)
            defaults.set(snap.recent, forKey: recentKey)
            if backup, let data = try? JSONEncoder().encode(snap) {
                let store = NSUbiquitousKeyValueStore.default
                store.set(data, forKey: iCloudKey)
                store.synchronize()
            }
        }
        if background { Self.io.async(execute: job) } else { Self.io.sync(execute: job) }
    }

    func boost(for word: String, previous: String?) -> Double {
        // libchewing's raw frequency weights routinely differ by 5,000-40,000 between
        // homophone competitors (e.g. 業 49775 vs 易 14785) — the old +50/+120-per-pick
        // constants (tuned for the old, much flatter rime corpus) were noise against that
        // gap, so a picked word never visibly moved up. Scaled to the same order of
        // magnitude as toneScore's ±12,000/-18,000 so a few picks reliably win.
        var score = Double(freq[word, default: 0]) * 4_000
        if let previous, let count = next[previous]?[word] {
            score += Double(count) * 8_000
        }
        return score
    }

    /// Predictions after a committed word.
    func predictions(after word: String, limit: Int = 6) -> [String] {
        guard let followers = next[word] else { return [] }
        return Array(followers.sorted { $0.value > $1.value }.prefix(limit).map(\.key))
    }

    var statsSummary: String {
        "詞頻 \(freq.count) · 搭配 \(bigram.count) · 最近 \(recent.count)"
    }

    // MARK: - File backup

    func makeSnapshot() -> Snapshot {
        Snapshot(freq: freq, bigram: bigram, recent: recent, exportedAt: Date())
    }

    func exportJSON() throws -> Data {
        try JSONEncoder().encode(makeSnapshot())
    }

    @discardableResult
    func importJSON(_ data: Data, merge: Bool) throws -> Snapshot {
        let snap = try JSONDecoder().decode(Snapshot.self, from: data)
        apply(snapshot: snap, merge: merge)
        return snap
    }

    private func apply(snapshot: Snapshot, merge: Bool) {
        if merge {
            for (k, v) in snapshot.freq {
                freq[k, default: 0] = max(freq[k, default: 0], v)
            }
            for (k, v) in snapshot.bigram {
                bigram[k, default: 0] = max(bigram[k, default: 0], v)
            }
            recent = Array((snapshot.recent + recent).suffix(64))
        } else {
            freq = snapshot.freq
            bigram = snapshot.bigram
            recent = snapshot.recent
        }
        Self.prune(&freq, max: Self.maxFreq)
        Self.prune(&bigram, max: Self.maxBigram)
        rebuildNext()
        persist()
    }

    // MARK: - iCloud KVS (works when app is properly signed + iCloud on)

    @discardableResult
    func backupToiCloud() -> Bool {
        guard let data = try? exportJSON() else { return false }
        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: iCloudKey)
        return store.synchronize()
    }

    @discardableResult
    func restoreFromiCloud(merge: Bool) -> Bool {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard let data = store.data(forKey: iCloudKey) else { return false }
        do {
            _ = try importJSON(data, merge: merge)
            return true
        } catch {
            return false
        }
    }

    private func persist() {
        defaults.set(freq, forKey: freqKey)
        defaults.set(bigram, forKey: bigramKey)
        defaults.set(recent, forKey: recentKey)
    }
}
