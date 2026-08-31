import UIKit

final class ZhuyinKeyboardView: UIView {
    var onAction: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onMode: (() -> Void)?

    /// Match Hamster `buttonInsets` (~3pt) and row heights without an extra mode strip.
    private let interKey: CGFloat = 5
    private let interRow: CGFloat = 6
    private let sideFrac: CGFloat = 0.16
    private let midFrac: CGFloat = 0.226

    private var keyButtons: [KeyButton] = []
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        separator.backgroundColor = UIColor(white: 0.55, alpha: 0.55)
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)
        buildKeys()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutKeys()
    }

    private func buildKeys() {
        for row in ZhuyinPhoneLayout.rows {
            for key in row.keys {
                let btn = KeyButton(label: key.label, action: key.action)
                btn.onTap = { [weak self] action in
                    self?.onAction?(action)
                }
                btn.onLongPressCallout = key.callouts.map { ($0.label, $0.action) }
                // Long-press space → EN (avoid extra row that breaks Hamster proportions)
                if case .space = key.action {
                    let lpEN = UILongPressGestureRecognizer(target: self, action: #selector(spaceLongPressEN(_:)))
                    lpEN.minimumPressDuration = 0.45
                    btn.addGestureRecognizer(lpEN)
                }
                addSubview(btn)
                keyButtons.append(btn)
            }
        }
        // Tiny EN / emoji in the bottom-left gutter (does not steal row height)
        let en = UIButton(type: .system)
        en.setTitle("EN", for: .normal)
        en.titleLabel?.font = .systemFont(ofSize: 11, weight: .semibold)
        en.tag = 9001
        en.addAction(UIAction { [weak self] _ in self?.onMode?() }, for: .touchUpInside)
        addSubview(en)

        let emoji = UIButton(type: .system)
        emoji.setTitle("🙂", for: .normal)
        emoji.titleLabel?.font = .systemFont(ofSize: 12)
        emoji.tag = 9002
        emoji.addAction(UIAction { _ in
            NotificationCenter.default.post(name: .t9SwitchEmoji, object: nil)
        }, for: .touchUpInside)
        addSubview(emoji)
    }

    @objc private func spaceLongPressEN(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        onMode?()
    }

    private func layoutKeys() {
        let bounds = self.bounds.insetBy(dx: 3, dy: 3)
        guard bounds.width > 1, bounds.height > 1 else { return }

        let rows = 4
        let cols = 5
        let rowH = (bounds.height - interRow * CGFloat(rows - 1)) / CGFloat(rows)
        // Widths: side / mid / mid / mid / side  (Hamster percentages)
        let gaps = interKey * CGFloat(cols - 1)
        let usable = bounds.width - gaps
        let sideW = usable * sideFrac
        let midW = usable * midFrac
        // Normalize in case of float drift so total fills usable width
        let widths = [sideW, midW, midW, midW, sideW]
        let widthSum = widths.reduce(0, +)
        let scale = usable / widthSum
        let colW = widths.map { $0 * scale }

        // Vertical separator just before the right function column
        let sepX = bounds.minX + colW[0] + interKey + colW[1] + interKey + colW[2] + interKey + colW[3] + interKey * 0.5
        separator.frame = CGRect(x: sepX - 0.5, y: bounds.minY + 2, width: 1, height: bounds.height - 4)

        var idx = 0
        for r in 0..<rows {
            var x = bounds.minX
            let y = bounds.minY + CGFloat(r) * (rowH + interRow)
            for c in 0..<cols {
                let btn = keyButtons[idx]
                btn.frame = CGRect(x: x, y: y, width: colW[c], height: rowH)
                x += colW[c] + interKey
                idx += 1
            }
        }

        if let en = viewWithTag(9001), let emoji = viewWithTag(9002) {
            // Sit in the bottom safe strip overlapping tone/space gutter slightly
            en.frame = CGRect(x: bounds.minX + 2, y: bounds.maxY - 18, width: 28, height: 16)
            emoji.frame = CGRect(x: bounds.minX + 30, y: bounds.maxY - 18, width: 22, height: 16)
        }
    }
}

extension Notification.Name {
    static let t9SwitchEmoji = Notification.Name("t9SwitchEmoji")
}

final class KeyButton: UIButton {
    var onTap: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onLongPressCallout: [(label: String, action: ZhuyinPhoneLayout.KeyAction)] = []
    private let keyAction: ZhuyinPhoneLayout.KeyAction

    init(label: String, action: ZhuyinPhoneLayout.KeyAction) {
        self.keyAction = action
        super.init(frame: .zero)
        setTitle(label, for: .normal)
        setTitleColor(.black, for: .normal)
        let isTone = label.count <= 1 && "ˉˊˇˋ".contains(label)
        let isFunc = ["⌫", "123", "。", "換行", "空格"].contains(label)
        titleLabel?.font = .systemFont(
            ofSize: isTone ? 20 : (label.count > 3 ? 13 : (isFunc ? 15 : 15)),
            weight: .medium
        )
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.7
        backgroundColor = .white
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0.5
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        addGestureRecognizer(lp)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() {
        onTap?(keyAction)
    }

    @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let first = onLongPressCallout.first else { return }
        onTap?(first.action)
    }
}
