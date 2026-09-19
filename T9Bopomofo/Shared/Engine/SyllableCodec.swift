import Foundation

/// Converts zhuyin (bopomofo) readings — e.g. `ㄗㄠˇ`, `ㄘㄢ` — into T9 digit
/// sequences via `T9KeyMap`. Also passes through literal ASCII syllables
/// (brand names spelled letter-by-letter, e.g. `card`, `P`) unchanged.
enum SyllableCodec {
    struct EncodedSyllable {
        /// T9 keys for this syllable, e.g. ㄗㄠ → "38".
        let digits: String
        /// Tone key: q/w/x/y (1/2/3/4), or ˙ for neutral (輕聲). No tone info → nil.
        let tone: Character?
    }

    private static let toneMarks: [Character: Character] = ["ˊ": "w", "ˇ": "x", "ˋ": "y"]
    private static let bopomofoBlock: ClosedRange<UInt32> = 0x3105...0x312F

    static func encodeSyllable(_ raw: String) -> EncodedSyllable? {
        var chars = Array(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !chars.isEmpty else { return nil }

        var tone: Character?
        if let last = chars.last {
            if let mapped = toneMarks[last] {
                tone = mapped
                chars.removeLast()
            } else if last == "˙" {
                chars.removeLast()
                // Its own tone, so the ˙ key can anchor it. It used to leave `tone` nil and fall
                // into the tone-1 default below, so 的/嗎/吧 scored as first tone.
                tone = "˙"
            }
        }

        // Bare zhuyin syllable (no mark) defaults to tone 1.
        if tone == nil, chars.allSatisfy({ bopomofoBlock.contains($0.unicodeScalars.first?.value ?? 0) }) {
            tone = "q"
        }

        var digits = ""
        for ch in chars {
            guard let key = T9KeyMap.tokenToKey[ch] else { continue }
            digits.append(key)
        }
        guard !digits.isEmpty else { return nil }
        return EncodedSyllable(digits: digits, tone: tone)
    }

    static func encodeReading(_ reading: String) -> (digits: String, tones: String, syllableLengths: String) {
        var digits = ""
        var tones = ""
        var syllableLengths = ""  // one digit char per syllable; a zhuyin syllable is at most 4 keys
        for part in reading.split(separator: " ") {
            guard let enc = encodeSyllable(String(part)) else { continue }
            digits += enc.digits
            tones.append(enc.tone ?? "-")
            syllableLengths += String(enc.digits.count)
        }
        return (digits, tones, syllableLengths)
    }
}
