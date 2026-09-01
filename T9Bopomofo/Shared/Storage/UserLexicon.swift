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
        }
        recent.append(word)
        if recent.count > 64 { recent.removeFirst(recent.count - 64) }
        persist()
        if AppSettings.shared.iCloudAutoBackup {
            backupToiCloud()
        }
    }

    func boost(for word: String, previous: String?) -> Double {
        var score = Double(freq[word, default: 0]) * 50
        if let previous {
            let key = previous + "\u{1f}" + word
            score += Double(bigram[key, default: 0]) * 120
        }
        return score
    }

    /// Predictions after a committed word.
    func predictions(after word: String, limit: Int = 6) -> [String] {
        let prefix = word + "\u{1f}"
        let ranked = bigram
            .filter { $0.key.hasPrefix(prefix) }
            .map { (String($0.key.dropFirst(prefix.count)), $0.value) }
            .sorted { $0.1 > $1.1 }
        return Array(ranked.prefix(limit).map(\.0))
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
