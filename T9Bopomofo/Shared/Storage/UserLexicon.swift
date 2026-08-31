import Foundation

/// Local learning + simple bigram context (App Group / UserDefaults).
final class UserLexicon: @unchecked Sendable {
    private let defaults: UserDefaults
    private let freqKey = "user_word_freq_v1"
    private let bigramKey = "user_bigram_v1"
    private let recentKey = "user_recent_commits_v1"

    private var freq: [String: Int]
    private var bigram: [String: Int]
    private var recent: [String]

    init(suiteName: String = "group.com.jo1project.t9bopomofo") {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
        freq = defaults.dictionary(forKey: freqKey) as? [String: Int] ?? [:]
        bigram = defaults.dictionary(forKey: bigramKey) as? [String: Int] ?? [:]
        recent = defaults.stringArray(forKey: recentKey) ?? []
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

    private func persist() {
        defaults.set(freq, forKey: freqKey)
        defaults.set(bigram, forKey: bigramKey)
        defaults.set(recent, forKey: recentKey)
    }
}
