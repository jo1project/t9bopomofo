import Foundation

/// Converts Rime-style pinyin readings (e.g. `zao3`, `la1`) into T9 digit sequences
/// using the same algebra as `bopomofo_phone.schema.yaml`.
enum SyllableCodec {
    struct EncodedSyllable {
        /// T9 keys without tone, e.g. `zao` → keys for ㄗㄠ
        let digits: String
        /// Optional tone key: q/w/x/y (1/2/3/4). Tone 5 / neutral → nil.
        let tone: Character?
    }

    static func encodePinyinSyllable(_ raw: String) -> EncodedSyllable? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var s = trimmed.lowercased()
        var tone: Character?
        if let last = s.last, let t = toneFromDigit(last) {
            tone = t
            s.removeLast()
        }

        // Schema algebra (order matters).
        s = apply("yong", "vP", in: s)
        s = apply("iong", "vP", in: s)
        s = apply("weng", "uP", in: s)
        s = apply("ong", "uP", in: s)
        s = apply("ing", "iP", in: s)

        if s.hasPrefix("yu") { s = "v" + s.dropFirst(2) }
        if s.hasPrefix("yi") { s = "i" + s.dropFirst(2) }
        else if s.hasPrefix("y") { s = "i" + s.dropFirst() }
        if s.hasPrefix("wu") { s = "u" + s.dropFirst(2) }
        else if s.hasPrefix("w") { s = "u" + s.dropFirst() }

        s = apply("iu", "iou", in: s)
        s = apply("ui", "uei", in: s)

        // j/q/x + u → v  (q/x already mapped later via A/B; here use letters)
        s = replaceInitialJu(s)

        s = apply("in", "ien", in: s) // ([iuv])n → $1en ; handle i/u/v n
        s = apply("un", "uen", in: s)
        s = apply("vn", "ven", in: s)

        s = apply("zhi", "Z", in: s)
        s = apply("chi", "C", in: s)
        s = apply("shi", "S", in: s)
        if s.hasPrefix("zh") { s = "Z" + s.dropFirst(2) }
        if s.hasPrefix("ch") { s = "C" + s.dropFirst(2) }
        if s.hasPrefix("sh") { s = "S" + s.dropFirst(2) }

        // zi/ci/si/ri → z/c/s/r
        for ch in ["z", "c", "s", "r"] where s == ch + "i" {
            s = ch
        }

        s = apply("ai", "I", in: s)
        s = apply("ei", "J", in: s)
        s = apply("ao", "K", in: s)
        s = apply("ou", "L", in: s)
        s = apply("ang", "O", in: s)
        s = apply("eng", "P", in: s)
        s = apply("an", "M", in: s)
        s = apply("en", "N", in: s)
        s = apply("er", "R", in: s)
        s = apply("eh", "E", in: s)
        // ([iv])e → $1E
        s = s.replacingOccurrences(of: "ie", with: "iE")
        s = s.replacingOccurrences(of: "ve", with: "vE")

        // q→A, x→B (schema does this early; pinyin rarely has raw q/x as finals)
        s = s.replacingOccurrences(of: "q", with: "A")
        s = s.replacingOccurrences(of: "x", with: "B")

        var digits = ""
        for ch in s {
            guard let key = T9KeyMap.tokenToKey[ch] else {
                // Unknown token — fail soft by skipping
                continue
            }
            digits.append(key)
        }
        guard !digits.isEmpty else { return nil }
        return EncodedSyllable(digits: digits, tone: tone)
    }

    static func encodeReading(_ reading: String) -> (digits: String, tones: String) {
        let parts = reading.split(whereSeparator: { $0 == " " || $0 == "'" }).map(String.init)
        var digits = ""
        var tones = ""
        for part in parts {
            guard let enc = encodePinyinSyllable(part) else { continue }
            digits += enc.digits
            tones.append(enc.tone ?? "-")
        }
        return (digits, tones)
    }

    // MARK: - Helpers

    private static func toneFromDigit(_ c: Character) -> Character? {
        switch c {
        case "1": return "q"
        case "2": return "w"
        case "3": return "x"
        case "4": return "y"
        case "5": return nil
        default: return nil
        }
    }

    private static func apply(_ from: String, _ to: String, in s: String) -> String {
        s.replacingOccurrences(of: from, with: to)
    }

    private static func replaceInitialJu(_ s: String) -> String {
        var out = s
        for initial in ["j", "A", "B"] {
            let needle = initial + "u"
            if out.hasPrefix(needle) {
                out = initial + "v" + out.dropFirst(2)
            }
        }
        return out
    }
}
