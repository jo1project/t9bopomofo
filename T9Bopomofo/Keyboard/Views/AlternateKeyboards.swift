import UIKit

final class EnglishKeyboardView: UIView {
    var onInsert: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onMode: ((KeyboardMode) -> Void)?

    private enum ShiftState {
        case off
        case once   // next letter uppercase, then off
        case caps   // locked uppercase
    }

    private var shiftState: ShiftState = .off
    private let letterRows: [[Character]] = [
        Array("qwertyuiop"),
        Array("asdfghjkl"),
        Array("zxcvbnm"),
    ]

    private let root = UIStackView()
    private var letterButtons: [UIButton] = []
    private var shiftButton: UIButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        root.axis = .vertical
        root.spacing = 4
        root.distribution = .fillEqually
        root.translatesAutoresizingMaskIntoConstraints = false
        addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: topAnchor),
            root.leadingAnchor.constraint(equalTo: leadingAnchor),
            root.trailingAnchor.constraint(equalTo: trailingAnchor),
            root.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func rebuild() {
        root.arrangedSubviews.forEach {
            root.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        letterButtons = []

        for (rowIndex, letters) in letterRows.enumerated() {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 4
            row.distribution = .fillEqually

            if rowIndex == 2 {
                let shift = makeKey(shiftTitle(), isFunction: true) { [weak self] in
                    self?.cycleShift()
                }
                shiftButton = shift
                row.addArrangedSubview(shift)
                // Weight: shift slightly wider via hugging — stack is fillEqually so add spacer pattern
            }

            for ch in letters {
                let btn = makeKey(display(ch), isFunction: false) { [weak self] in
                    self?.insertLetter(ch)
                }
                letterButtons.append(btn)
                row.addArrangedSubview(btn)
            }

            if rowIndex == 2 {
                let bs = makeKey("⌫", isFunction: true, addTap: false)
                enableRepeatDelete(on: bs) { [weak self] in
                    self?.onBackspace?()
                }
                row.addArrangedSubview(bs)
            }
            root.addArrangedSubview(row)
        }

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 4
        bottom.distribution = .fillEqually
        bottom.addArrangedSubview(makeKey("注", isFunction: true) { [weak self] in self?.onMode?(.zhuyin) })
        bottom.addArrangedSubview(makeKey("123", isFunction: true) { [weak self] in self?.onMode?(.symbols) })
        bottom.addArrangedSubview(makeKey("space", isFunction: false) { [weak self] in self?.onInsert?(" ") })
        bottom.addArrangedSubview(makeKey("🙂", isFunction: true) { [weak self] in self?.onMode?(.emoji) })
        bottom.addArrangedSubview(makeKey("return", isFunction: true) { [weak self] in self?.onInsert?("\n") })
        root.addArrangedSubview(bottom)

        refreshShiftAppearance()
    }

    private func display(_ ch: Character) -> String {
        let s = String(ch)
        switch shiftState {
        case .off: return s
        case .once, .caps: return s.uppercased()
        }
    }

    private func shiftTitle() -> String {
        switch shiftState {
        case .off: return "⇧"
        case .once: return "⇧"
        case .caps: return "⇪"
        }
    }

    private func cycleShift() {
        switch shiftState {
        case .off: shiftState = .once
        case .once: shiftState = .caps
        case .caps: shiftState = .off
        }
        refreshLetterTitles()
        refreshShiftAppearance()
    }

    private func insertLetter(_ ch: Character) {
        let s = display(ch)
        onInsert?(s)
        if shiftState == .once {
            shiftState = .off
            refreshLetterTitles()
            refreshShiftAppearance()
        }
    }

    private func refreshLetterTitles() {
        // Rebuild is heavy; update titles in place.
        var i = 0
        for letters in letterRows {
            for ch in letters {
                guard i < letterButtons.count else { return }
                letterButtons[i].setTitle(display(ch), for: .normal)
                i += 1
            }
        }
        shiftButton?.setTitle(shiftTitle(), for: .normal)
    }

    private func refreshShiftAppearance() {
        guard let shiftButton else { return }
        switch shiftState {
        case .off:
            shiftButton.backgroundColor = UIColor(white: 0.72, alpha: 1)
            shiftButton.setTitleColor(.black, for: .normal)
        case .once:
            shiftButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.85)
            shiftButton.setTitleColor(.white, for: .normal)
        case .caps:
            shiftButton.backgroundColor = UIColor.systemBlue
            shiftButton.setTitleColor(.white, for: .normal)
        }
        shiftButton.setTitle(shiftTitle(), for: .normal)
    }

    private func makeKey(_ title: String, isFunction: Bool, addTap: Bool = true, _ action: (() -> Void)? = nil) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.black, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: title == "space" || title == "return" ? 14 : 18, weight: .medium)
        b.backgroundColor = isFunction ? UIColor(white: 0.72, alpha: 1) : .white
        b.layer.cornerRadius = 6
        if addTap, let action {
            b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        }
        return b
    }

    private func enableRepeatDelete(on button: UIButton, _ handler: @escaping () -> Void) {
        final class TimerBox {
            var timer: Timer?
        }
        let box = TimerBox()
        button.addAction(UIAction { _ in
            handler()
            box.timer?.invalidate()
            let delay = Timer(timeInterval: 0.4, repeats: false) { _ in
                box.timer?.invalidate()
                let fast = Timer(timeInterval: 0.07, repeats: true) { _ in
                    handler()
                }
                RunLoop.main.add(fast, forMode: .common)
                box.timer = fast
            }
            RunLoop.main.add(delay, forMode: .common)
            box.timer = delay
        }, for: .touchDown)
        let stop = UIAction { _ in
            box.timer?.invalidate()
            box.timer = nil
        }
        button.addAction(stop, for: .touchUpInside)
        button.addAction(stop, for: .touchUpOutside)
        button.addAction(stop, for: .touchCancel)
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
        root.spacing = 4
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
