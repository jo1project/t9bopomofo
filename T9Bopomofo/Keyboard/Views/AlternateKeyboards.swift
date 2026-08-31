import UIKit

final class EnglishKeyboardView: UIView {
    var onInsert: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onMode: ((KeyboardMode) -> Void)?

    private let rows = [
        Array("qwertyuiop"),
        Array("asdfghjkl"),
        Array("zxcvbnm"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 6
        root.distribution = .fillEqually
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for letters in rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 4
            row.distribution = .fillEqually
            for ch in letters {
                row.addArrangedSubview(makeKey(String(ch)) { [weak self] in
                    self?.onInsert?(String(ch))
                })
            }
            root.addArrangedSubview(row)
        }

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 4
        bottom.distribution = .fillEqually
        bottom.addArrangedSubview(makeKey("注") { [weak self] in self?.onMode?(.zhuyin) })
        bottom.addArrangedSubview(makeKey("123") { [weak self] in self?.onMode?(.symbols) })
        bottom.addArrangedSubview(makeKey("space") { [weak self] in self?.onInsert?(" ") })
        bottom.addArrangedSubview(makeKey("🙂") { [weak self] in self?.onMode?(.emoji) })
        bottom.addArrangedSubview(makeKey("⌫") { [weak self] in self?.onBackspace?() })
        root.addArrangedSubview(bottom)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeKey(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.backgroundColor = .white
        b.layer.cornerRadius = 6
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }
}

final class SymbolKeyboardView: UIView {
    var onInsert: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onMode: ((KeyboardMode) -> Void)?

    private let symbols = [
        Array("1234567890"),
        Array("-/:;()$&@\""),
        Array(".,?!'" ),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 6
        root.distribution = .fillEqually
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        for rowChars in symbols {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 4
            row.distribution = .fillEqually
            for ch in rowChars {
                let s = String(ch)
                row.addArrangedSubview(makeKey(s) { [weak self] in self?.onInsert?(s) })
            }
            root.addArrangedSubview(row)
        }
        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 4
        bottom.distribution = .fillEqually
        bottom.addArrangedSubview(makeKey("注") { [weak self] in self?.onMode?(.zhuyin) })
        bottom.addArrangedSubview(makeKey("EN") { [weak self] in self?.onMode?(.english) })
        bottom.addArrangedSubview(makeKey("。") { [weak self] in self?.onInsert?("。") })
        bottom.addArrangedSubview(makeKey("，") { [weak self] in self?.onInsert?("，") })
        bottom.addArrangedSubview(makeKey("⌫") { [weak self] in self?.onBackspace?() })
        root.addArrangedSubview(bottom)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeKey(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.backgroundColor = .white
        b.layer.cornerRadius = 6
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }
}

final class EmojiKeyboardView: UIView {
    var onInsert: ((String) -> Void)?
    var onMode: ((KeyboardMode) -> Void)?

    private let emojis = ["😀", "😂", "😍", "🤔", "👍", "🙏", "🔥", "✨", "🎉", "❤️", "💯", "🥲", "👏", "🙌", "🍔", "☕"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 6
        grid.distribution = .fillEqually
        for chunk in stride(from: 0, to: emojis.count, by: 4).map({ Array(emojis[$0..<min($0+4, emojis.count)]) }) {
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 6
            for e in chunk {
                let b = UIButton(type: .system)
                b.setTitle(e, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 28)
                b.addAction(UIAction { [weak self] _ in self?.onInsert?(e) }, for: .touchUpInside)
                row.addArrangedSubview(b)
            }
            grid.addArrangedSubview(row)
        }
        root.addArrangedSubview(grid)

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.distribution = .fillEqually
        let back = UIButton(type: .system)
        back.setTitle("注音", for: .normal)
        back.addAction(UIAction { [weak self] _ in self?.onMode?(.zhuyin) }, for: .touchUpInside)
        bottom.addArrangedSubview(back)
        root.addArrangedSubview(bottom)
    }

    required init?(coder: NSCoder) { fatalError() }
}
