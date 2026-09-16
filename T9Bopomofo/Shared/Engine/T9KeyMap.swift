import Foundation

/// T9 digit map from `bopomofo_phone` / `zhuyin_phone` layout.
enum T9KeyMap {
    /// Exact zhuyin token (schema internal letter) → T9 key character.
    static let tokenToKey: [Character: Character] = [
        "b": "1", "d": "1", "a": "1",
        "g": "2", "j": "2", "I": "2",
        "Z": "3", "z": "3", "M": "3", "R": "3",
        "p": "4", "t": "4", "o": "4",
        "k": "5", "A": "5", "J": "5",
        "C": "6", "c": "6", "N": "6", "i": "6",
        "m": "7", "n": "7", "e": "7",
        "h": "8", "B": "8", "K": "8", "L": "8",
        "S": "9", "s": "9", "O": "9", "u": "9",
        "f": "0", "l": "0", "E": "0",
        "r": "v", "P": "v", "v": "v",

        // Zhuyin (bopomofo) symbols, one physical key per group — same grouping as `keyLabels`.
        "ㄅ": "1", "ㄉ": "1", "ㄚ": "1",
        "ㄍ": "2", "ㄐ": "2", "ㄞ": "2",
        "ㄓ": "3", "ㄗ": "3", "ㄢ": "3", "ㄦ": "3",
        "ㄆ": "4", "ㄊ": "4", "ㄛ": "4",
        "ㄎ": "5", "ㄑ": "5", "ㄟ": "5",
        "ㄔ": "6", "ㄘ": "6", "ㄣ": "6", "ㄧ": "6",
        "ㄇ": "7", "ㄋ": "7", "ㄜ": "7",
        "ㄏ": "8", "ㄒ": "8", "ㄠ": "8", "ㄡ": "8",
        "ㄕ": "9", "ㄙ": "9", "ㄤ": "9", "ㄨ": "9",
        "ㄈ": "0", "ㄌ": "0", "ㄝ": "0",
        "ㄖ": "v", "ㄥ": "v", "ㄩ": "v",
    ]

    /// Tone keys on the left column (optional).
    static let toneKeys: Set<Character> = ["q", "w", "x", "y"]

    /// Physical neighbors on the zhuyin_phone middle grid (for fuzzy).
    static let neighbors: [Character: [Character]] = [
        "1": ["2", "4"],
        "2": ["1", "3", "5"],
        "3": ["2", "6"],
        "4": ["1", "5", "7"],
        "5": ["2", "4", "6", "8"],
        "6": ["3", "5", "9"],
        "7": ["4", "8", "0"],
        "8": ["5", "7", "9", "v"],
        "9": ["6", "8", "v"],
        "0": ["7", "v"],
        "v": ["8", "9", "0"],
    ]

    static let keyLabels: [Character: String] = [
        "1": "ㄅㄉㄚ",
        "2": "ㄍㄐㄞ",
        "3": "ㄓㄗㄢㄦ",
        "4": "ㄆㄊㄛ",
        "5": "ㄎㄑㄟ",
        "6": "ㄔㄘㄣㄧ",
        "7": "ㄇㄋㄜ",
        "8": "ㄏㄒㄠㄡ",
        "9": "ㄕㄙㄤㄨ",
        "0": "ㄈㄌㄝ",
        "v": "ㄖㄥㄩ",
    ]
}
