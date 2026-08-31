import UIKit

final class ZhuyinKeyboardView: UIView {
    var onAction: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onMode: (() -> Void)?

    private let grid = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        grid.axis = .vertical
        grid.spacing = 6
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: topAnchor),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        for row in ZhuyinPhoneLayout.rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 5
            rowStack.distribution = .fill
            for key in row.keys {
                let btn = KeyButton(label: key.label, action: key.action)
                btn.onTap = { [weak self] action in
                    self?.onAction?(action)
                }
                btn.onLongPressCallout = key.callouts.map { ($0.label, $0.action) }
                rowStack.addArrangedSubview(btn)
                btn.widthAnchor.constraint(equalTo: rowStack.widthAnchor, multiplier: key.width).isActive = true
            }
            // Globe / mode switch is system-provided beside our keys; add EN shortcut on space long-press via corner.
            grid.addArrangedSubview(rowStack)
        }

        // Mode row overlay: small EN / 🙂 buttons floating isn't in layout — add a thin strip.
        let modeRow = UIStackView()
        modeRow.axis = .horizontal
        modeRow.spacing = 8
        let en = UIButton(type: .system)
        en.setTitle("EN", for: .normal)
        en.addAction(UIAction { [weak self] _ in self?.onMode?() }, for: .touchUpInside)
        let emoji = UIButton(type: .system)
        emoji.setTitle("🙂", for: .normal)
        emoji.addAction(UIAction { _ in
            NotificationCenter.default.post(name: .t9SwitchEmoji, object: nil)
        }, for: .touchUpInside)
        modeRow.addArrangedSubview(en)
        modeRow.addArrangedSubview(emoji)
        modeRow.addArrangedSubview(UIView())
        grid.addArrangedSubview(modeRow)
        modeRow.heightAnchor.constraint(equalToConstant: 28).isActive = true
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
        titleLabel?.font = .systemFont(ofSize: label.count > 2 ? 14 : 18, weight: .medium)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
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
        // Simple: first callout on long press; full callout UI later.
        onTap?(first.action)
    }
}
