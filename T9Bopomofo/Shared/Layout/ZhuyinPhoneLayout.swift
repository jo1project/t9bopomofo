import Foundation

/// Mirrors `Resources/layouts/zhuyin_phone.yaml` primary keyboard.
enum ZhuyinPhoneLayout {
    enum KeyAction: Equatable {
        case t9(Character)
        case tone(Character)       // q/w/x/y
        case toneNeutral           // soft tone ˙ (omit tone marker)
        case backspace
        case numberPad
        case symbol(String)
        case space
        case enter
        case exact(Character, label: String)
        case switchEnglish
        case switchEmoji
    }

    struct Callout: Identifiable {
        let id: String
        let label: String
        let action: KeyAction
    }

    struct Key: Identifiable {
        let id: String
        let label: String
        let width: Double
        let action: KeyAction
        let callouts: [Callout]
    }

    struct Row: Identifiable {
        let id: String
        let keys: [Key]
    }

    /// Shared punctuation callouts for 。 long-press.
    /// Brackets are placed early so they stay reachable on narrow screens.
    static let punctuationCallouts: [Callout] = [
        Callout(id: "，", label: "，", action: .symbol("，")),
        Callout(id: "？", label: "？", action: .symbol("？")),
        Callout(id: "！", label: "！", action: .symbol("！")),
        Callout(id: "、", label: "、", action: .symbol("、")),
        Callout(id: "「", label: "「", action: .symbol("「")),
        Callout(id: "」", label: "」", action: .symbol("」")),
        Callout(id: "『", label: "『", action: .symbol("『")),
        Callout(id: "』", label: "』", action: .symbol("』")),
        Callout(id: "（", label: "（", action: .symbol("（")),
        Callout(id: "）", label: "）", action: .symbol("）")),
        Callout(id: "【", label: "【", action: .symbol("【")),
        Callout(id: "】", label: "】", action: .symbol("】")),
        Callout(id: "…", label: "…", action: .symbol("…")),
        Callout(id: "：", label: "：", action: .symbol("：")),
        Callout(id: "；", label: "；", action: .symbol("；")),
        Callout(id: "～", label: "～", action: .symbol("～")),
        Callout(id: "—", label: "—", action: .symbol("—")),
        Callout(id: "@", label: "@", action: .symbol("@")),
        Callout(id: "#", label: "#", action: .symbol("#")),
    ]

    private static let soft = Callout(id: "˙", label: "˙", action: .toneNeutral)

    private static func toneCallouts(excluding primary: Character) -> [Callout] {
        let all: [(Character, String)] = [
            ("q", "ˉ"), ("w", "ˊ"), ("x", "ˇ"), ("y", "ˋ"),
        ]
        var out = all.filter { $0.0 != primary }.map {
            Callout(id: $0.1, label: $0.1, action: .tone($0.0))
        }
        out.append(soft)
        return out
    }

    static let rows: [Row] = [
        Row(id: "r0", keys: [
            Key(id: "tone1", label: "ˉ", width: 0.16, action: .tone("q"), callouts: toneCallouts(excluding: "q")),
            t9Key("1", "ㄅㄉㄚ", exact: [("ㄅ", "b"), ("ㄉ", "d"), ("ㄚ", "a")]),
            t9Key("2", "ㄍㄐㄞ", exact: [("ㄍ", "g"), ("ㄐ", "j"), ("ㄞ", "I")]),
            t9Key("3", "ㄓㄗㄢㄦ", exact: [("ㄓ", "Z"), ("ㄗ", "z"), ("ㄢ", "M"), ("ㄦ", "R")], reverseCallouts: true),
            Key(id: "bs", label: "⌫", width: 0.16, action: .backspace, callouts: []),
        ]),
        Row(id: "r1", keys: [
            Key(id: "tone2", label: "ˊ", width: 0.16, action: .tone("w"), callouts: toneCallouts(excluding: "w")),
            t9Key("4", "ㄆㄊㄛ", exact: [("ㄆ", "p"), ("ㄊ", "t"), ("ㄛ", "o")]),
            t9Key("5", "ㄎㄑㄟ", exact: [("ㄎ", "k"), ("ㄑ", "A"), ("ㄟ", "J")]),
            t9Key("6", "ㄔㄘㄣㄧ", exact: [("ㄔ", "C"), ("ㄘ", "c"), ("ㄣ", "N"), ("ㄧ", "i")], reverseCallouts: true),
            Key(id: "num", label: "123", width: 0.16, action: .numberPad, callouts: [
                Callout(id: "emoji", label: "🙂", action: .switchEmoji),
            ]),
        ]),
        Row(id: "r2", keys: [
            Key(id: "tone3", label: "ˇ", width: 0.16, action: .tone("x"), callouts: toneCallouts(excluding: "x")),
            t9Key("7", "ㄇㄋㄜ", exact: [("ㄇ", "m"), ("ㄋ", "n"), ("ㄜ", "e")]),
            t9Key("8", "ㄏㄒㄠㄡ", exact: [("ㄏ", "h"), ("ㄒ", "B"), ("ㄠ", "K"), ("ㄡ", "L")]),
            t9Key("9", "ㄕㄙㄤㄨ", exact: [("ㄕ", "S"), ("ㄙ", "s"), ("ㄤ", "O"), ("ㄨ", "u")], reverseCallouts: true),
            Key(id: "period", label: "。", width: 0.16, action: .symbol("。"), callouts: punctuationCallouts),
        ]),
        Row(id: "r3", keys: [
            Key(id: "tone4", label: "ˋ", width: 0.16, action: .tone("y"), callouts: toneCallouts(excluding: "y")),
            t9Key("0", "ㄈㄌㄝ", exact: [("ㄈ", "f"), ("ㄌ", "l"), ("ㄝ", "E")]),
            Key(id: "space", label: "空格/EN", width: 0.226, action: .space, callouts: [
                Callout(id: "en", label: "EN", action: .switchEnglish),
            ]),
            t9Key("v", "ㄖㄥㄩ", exact: [("ㄖ", "r"), ("ㄥ", "P"), ("ㄩ", "v")], reverseCallouts: true),
            Key(id: "enter", label: "換行", width: 0.16, action: .enter, callouts: []),
        ]),
    ]

    private static func t9Key(
        _ digit: String,
        _ label: String,
        exact: [(String, String)],
        reverseCallouts: Bool = false
    ) -> Key {
        var callouts = exact.map {
            Callout(id: $0.0, label: $0.0, action: .exact($0.1.first!, label: $0.0))
        }
        if reverseCallouts { callouts.reverse() }
        return Key(
            id: "t9-\(digit)",
            label: label,
            width: 0.226,
            action: .t9(digit.first!),
            callouts: callouts
        )
    }
}
