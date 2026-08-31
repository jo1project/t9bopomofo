import Foundation

/// Mirrors `Resources/layouts/zhuyin_phone.yaml` primary keyboard.
enum ZhuyinPhoneLayout {
    enum KeyAction: Equatable {
        case t9(Character)
        case tone(Character)
        case backspace
        case numberPad
        case symbol(String)
        case punctuationMenu  // 。 key → show common punctuation tray
        case space
        case enter
        case exact(Character, label: String)
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

    static let rows: [Row] = [
        Row(id: "r0", keys: [
            Key(id: "tone1", label: "ˉ", width: 0.16, action: .tone("q"), callouts: []),
            t9Key("1", "ㄅㄉㄚ", exact: [("ㄅ", "b"), ("ㄉ", "d"), ("ㄚ", "a")]),
            t9Key("2", "ㄍㄐㄞ", exact: [("ㄍ", "g"), ("ㄐ", "j"), ("ㄞ", "I")]),
            t9Key("3", "ㄓㄗㄢㄦ", exact: [("ㄓ", "Z"), ("ㄗ", "z"), ("ㄢ", "M"), ("ㄦ", "R")], reverseCallouts: true),
            Key(id: "bs", label: "⌫", width: 0.16, action: .backspace, callouts: []),
        ]),
        Row(id: "r1", keys: [
            Key(id: "tone2", label: "ˊ", width: 0.16, action: .tone("w"), callouts: []),
            t9Key("4", "ㄆㄊㄛ", exact: [("ㄆ", "p"), ("ㄊ", "t"), ("ㄛ", "o")]),
            t9Key("5", "ㄎㄑㄟ", exact: [("ㄎ", "k"), ("ㄑ", "A"), ("ㄟ", "J")]),
            t9Key("6", "ㄔㄘㄣㄧ", exact: [("ㄔ", "C"), ("ㄘ", "c"), ("ㄣ", "N"), ("ㄧ", "i")], reverseCallouts: true),
            Key(id: "num", label: "123", width: 0.16, action: .numberPad, callouts: []),
        ]),
        Row(id: "r2", keys: [
            Key(id: "tone3", label: "ˇ", width: 0.16, action: .tone("x"), callouts: []),
            t9Key("7", "ㄇㄋㄜ", exact: [("ㄇ", "m"), ("ㄋ", "n"), ("ㄜ", "e")]),
            t9Key("8", "ㄏㄒㄠㄡ", exact: [("ㄏ", "h"), ("ㄒ", "B"), ("ㄠ", "K"), ("ㄡ", "L")]),
            t9Key("9", "ㄕㄙㄤㄨ", exact: [("ㄕ", "S"), ("ㄙ", "s"), ("ㄤ", "O"), ("ㄨ", "u")], reverseCallouts: true),
            Key(id: "period", label: "。", width: 0.16, action: .punctuationMenu, callouts: [
                Callout(id: "。", label: "。", action: .symbol("。")),
                Callout(id: "，", label: "，", action: .symbol("，")),
                Callout(id: "？", label: "？", action: .symbol("？")),
                Callout(id: "！", label: "！", action: .symbol("！")),
                Callout(id: "、", label: "、", action: .symbol("、")),
                Callout(id: "…", label: "…", action: .symbol("…")),
                Callout(id: "：", label: "：", action: .symbol("：")),
                Callout(id: "；", label: "；", action: .symbol("；")),
                Callout(id: "「", label: "「", action: .symbol("「")),
                Callout(id: "」", label: "」", action: .symbol("」")),
                Callout(id: "（", label: "（", action: .symbol("（")),
                Callout(id: "）", label: "）", action: .symbol("）")),
                Callout(id: "~", label: "～", action: .symbol("～")),
                Callout(id: "@", label: "@", action: .symbol("@")),
                Callout(id: "#", label: "#", action: .symbol("#")),
            ]),
        ]),
        Row(id: "r3", keys: [
            Key(id: "tone4", label: "ˋ", width: 0.16, action: .tone("y"), callouts: []),
            t9Key("0", "ㄈㄌㄝ", exact: [("ㄈ", "f"), ("ㄌ", "l"), ("ㄝ", "E")]),
            Key(id: "space", label: "空格", width: 0.226, action: .space, callouts: []),
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
