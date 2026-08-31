import UIKit

final class ZhuyinKeyboardView: UIView {
    var onAction: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onMode: (() -> Void)?

    /// Closer to Hamster: slightly narrower sides, wider middle, taller keys.
    private let interKey: CGFloat = 6
    private let interRow: CGFloat = 7
    private let sideGapBeforeFunc: CGFloat = 10  // wider gutter before right column
    private let sideFrac: CGFloat = 0.145
    private let midFrac: CGFloat = 0.236

    private var keyButtons: [KeyButton] = []
    private let separator = UIView()
    private let modeBar = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.78, alpha: 1)
        separator.backgroundColor = UIColor(white: 0.45, alpha: 1)
        addSubview(separator)

        modeBar.axis = .horizontal
        modeBar.spacing = 10
        modeBar.alignment = .center
        addSubview(modeBar)
        buildKeys()
        buildModeBar()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutKeys()
    }

    private func buildModeBar() {
        let en = UIButton(type: .system)
        en.setTitle("EN", for: .normal)
        en.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        en.setTitleColor(.darkGray, for: .normal)
        en.addAction(UIAction { [weak self] _ in self?.onMode?() }, for: .touchUpInside)

        let emoji = UIButton(type: .system)
        emoji.setTitle("🙂", for: .normal)
        emoji.titleLabel?.font = .systemFont(ofSize: 14)
        emoji.addAction(UIAction { _ in
            NotificationCenter.default.post(name: .t9SwitchEmoji, object: nil)
        }, for: .touchUpInside)

        modeBar.addArrangedSubview(en)
        modeBar.addArrangedSubview(emoji)
        modeBar.addArrangedSubview(UIView())
    }

    private func buildKeys() {
        for row in ZhuyinPhoneLayout.rows {
            for key in row.keys {
                let isFunc = Self.isFunctionKey(key.action)
                let isTone = Self.isToneKey(key.action)
                let btn = KeyButton(label: key.label, action: key.action, style: isFunc ? .function : (isTone ? .tone : .zhuyin))
                btn.onTap = { [weak self] action in
                    self?.onAction?(action)
                }
                btn.onLongPressCallout = key.callouts.map { ($0.label, $0.action) }
                if case .space = key.action {
                    let lpEN = UILongPressGestureRecognizer(target: self, action: #selector(spaceLongPressEN(_:)))
                    lpEN.minimumPressDuration = 0.45
                    btn.addGestureRecognizer(lpEN)
                }
                addSubview(btn)
                keyButtons.append(btn)
            }
        }
    }

    private static func isFunctionKey(_ action: ZhuyinPhoneLayout.KeyAction) -> Bool {
        switch action {
        case .backspace, .numberPad, .symbol, .enter: return true
        default: return false
        }
    }

    private static func isToneKey(_ action: ZhuyinPhoneLayout.KeyAction) -> Bool {
        if case .tone = action { return true }
        return false
    }

    @objc private func spaceLongPressEN(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        onMode?()
    }

    private func layoutKeys() {
        let modeH: CGFloat = 22
        let bounds = CGRect(
            x: 4,
            y: 4,
            width: self.bounds.width - 8,
            height: self.bounds.height - 8 - modeH - 2
        )
        guard bounds.width > 1, bounds.height > 1 else { return }

        modeBar.frame = CGRect(x: 8, y: self.bounds.height - modeH - 2, width: 80, height: modeH)

        let rows = 4
        let cols = 5
        let rowH = (bounds.height - interRow * CGFloat(rows - 1)) / CGFloat(rows)

        // gaps: normal between 0-1,1-2,2-3; wider before function col (3-4)
        let normalGaps = interKey * 3
        let usable = bounds.width - normalGaps - sideGapBeforeFunc
        let sideW = usable * sideFrac
        let midW = usable * midFrac
        var widths = [sideW, midW, midW, midW, sideW]
        let widthSum = widths.reduce(0, +)
        let scale = usable / widthSum
        widths = widths.map { $0 * scale }

        let gaps: [CGFloat] = [interKey, interKey, interKey, sideGapBeforeFunc]

        // Separator in the wider gutter before function column
        var sepX = bounds.minX + widths[0] + gaps[0] + widths[1] + gaps[1] + widths[2] + gaps[2] + widths[3]
        sepX += sideGapBeforeFunc * 0.45
        separator.frame = CGRect(x: sepX - 1, y: bounds.minY + 4, width: 2, height: bounds.height - 8)
        bringSubviewToFront(separator)

        var idx = 0
        for r in 0..<rows {
            var x = bounds.minX
            let y = bounds.minY + CGFloat(r) * (rowH + interRow)
            for c in 0..<cols {
                let btn = keyButtons[idx]
                btn.frame = CGRect(x: x, y: y, width: widths[c], height: rowH)
                x += widths[c] + (c < 4 ? gaps[c] : 0)
                idx += 1
            }
        }
    }
}

extension Notification.Name {
    static let t9SwitchEmoji = Notification.Name("t9SwitchEmoji")
}

final class KeyButton: UIButton {
    enum Style {
        case zhuyin
        case tone
        case function
    }

    var onTap: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onLongPressCallout: [(label: String, action: ZhuyinPhoneLayout.KeyAction)] = []
    private let keyAction: ZhuyinPhoneLayout.KeyAction

    init(label: String, action: ZhuyinPhoneLayout.KeyAction, style: Style) {
        self.keyAction = action
        super.init(frame: .zero)
        setTitle(label, for: .normal)
        setTitleColor(.black, for: .normal)
        let fontSize: CGFloat
        switch style {
        case .tone: fontSize = 22
        case .function: fontSize = label == "換行" ? 15 : 16
        case .zhuyin: fontSize = label.count >= 4 ? 14 : (label == "空格" ? 15 : 16)
        }
        titleLabel?.font = .systemFont(ofSize: fontSize, weight: .medium)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.65

        switch style {
        case .function:
            backgroundColor = UIColor(white: 0.72, alpha: 1)
        case .tone:
            backgroundColor = UIColor(white: 0.92, alpha: 1)
        case .zhuyin:
            backgroundColor = .white
        }
        layer.cornerRadius = 7
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0.5
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        addGestureRecognizer(lp)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?(keyAction) }

    @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let first = onLongPressCallout.first else { return }
        onTap?(first.action)
    }
}
