import UIKit

final class ZhuyinKeyboardView: UIView {
    var onAction: ((ZhuyinPhoneLayout.KeyAction) -> Void)?
    var onMode: (() -> Void)?

    private let interKey: CGFloat = 5
    private let interRow: CGFloat = 4
    private let sideGapBeforeFunc: CGFloat = 8
    private let sideFrac: CGFloat = 0.155
    private let midFrac: CGFloat = 0.230
    private let edgeInset: CGFloat = 2

    private var keyButtons: [KeyButton] = []
    private let separator = UIView()
    private weak var activeCallout: KeyCalloutView?
    private weak var calloutHost: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyChrome()
        addSubview(separator)
        buildKeys()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChrome()
        for case let btn as KeyButton in keyButtons {
            btn.applyChrome(traits: traitCollection)
        }
    }

    private func applyChrome() {
        backgroundColor = KeyboardChrome.background(for: traitCollection)
        separator.backgroundColor = traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.4, alpha: 1)
            : UIColor(white: 0.45, alpha: 1)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutKeys()
    }

    private func buildKeys() {
        for row in ZhuyinPhoneLayout.rows {
            for key in row.keys {
                let isFunc = Self.isFunctionKey(key.action)
                let isTone = Self.isToneKey(key.action)
                let btn = KeyButton(label: key.label, action: key.action, style: isFunc ? .function : (isTone ? .tone : .zhuyin))
                btn.onTap = { [weak self] action in
                    self?.dismissCallout()
                    self?.onAction?(action)
                }
                btn.setCallouts(key.callouts.map { ($0.label, $0.action) })
                btn.onCalloutBegin = { [weak self, weak btn] items in
                    guard let self, let btn else { return }
                    self.showCallout(from: btn, items: items)
                }
                btn.onCalloutMove = { [weak self] pointInWindow in
                    self?.updateCalloutSelection(windowPoint: pointInWindow)
                }
                btn.onCalloutEnd = { [weak self] in
                    self?.commitCallout()
                }
                btn.onCalloutCancel = { [weak self] in
                    self?.dismissCallout()
                }
                if case .backspace = key.action {
                    btn.enableRepeatDelete { [weak self] in
                        self?.onAction?(.backspace)
                    }
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

    private func layoutKeys() {
        let inset = edgeInset
        let bounds = CGRect(
            x: inset,
            y: inset,
            width: self.bounds.width - inset * 2,
            height: self.bounds.height - inset * 2
        )
        guard bounds.width > 1, bounds.height > 1 else { return }

        let rows = 4
        let cols = 5
        let rowH = (bounds.height - interRow * CGFloat(rows - 1)) / CGFloat(rows)

        let normalGaps = interKey * 3
        let usable = bounds.width - normalGaps - sideGapBeforeFunc
        let sideW = usable * sideFrac
        let midW = usable * midFrac
        var widths = [sideW, midW, midW, midW, sideW]
        let widthSum = widths.reduce(0, +)
        let scale = usable / widthSum
        widths = widths.map { $0 * scale }

        let gaps: [CGFloat] = [interKey, interKey, interKey, sideGapBeforeFunc]

        var sepX = bounds.minX + widths[0] + gaps[0] + widths[1] + gaps[1] + widths[2] + gaps[2] + widths[3]
        sepX += sideGapBeforeFunc * 0.45
        separator.frame = CGRect(x: sepX - 1, y: bounds.minY + 2, width: 2, height: bounds.height - 4)
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

    // MARK: - Callout

    private func showCallout(from button: KeyButton, items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)]) {
        dismissCallout()
        guard !items.isEmpty else { return }
        let host = window ?? self
        calloutHost = host
        let callout = KeyCalloutView()
        // Prefer centering default on a sensible pick for long punctuation lists.
        let initial = items.count > 6 ? min(2, items.count - 1) : 0
        callout.configure(items: items, selected: initial)
        callout.setInitialIndex(initial)
        let itemW: CGFloat = 48
        let w = min(max(CGFloat(items.count) * itemW + 8, 56), host.bounds.width - 12)
        let h: CGFloat = 56
        let btnFrame = button.convert(button.bounds, to: host)
        var x = btnFrame.midX - w / 2
        x = max(6, min(x, host.bounds.width - w - 6))
        let y = max(6, btnFrame.minY - h - 8)
        callout.frame = CGRect(x: x, y: y, width: w, height: h)
        host.addSubview(callout)
        activeCallout = callout
    }

    private func updateCalloutSelection(windowPoint: CGPoint) {
        guard let callout = activeCallout else { return }
        // In-place relative slide: use window X delta from press origin.
        callout.select(trackingWindowX: windowPoint.x)
    }

    private func commitCallout() {
        if let action = activeCallout?.selectedAction {
            KeyboardHaptics.commit()
            onAction?(action)
        }
        dismissCallout()
    }

    private func dismissCallout() {
        activeCallout?.removeFromSuperview()
        activeCallout = nil
        calloutHost = nil
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
    var onCalloutBegin: (([(label: String, action: ZhuyinPhoneLayout.KeyAction)]) -> Void)?
    var onCalloutMove: ((CGPoint) -> Void)?
    var onCalloutEnd: (() -> Void)?
    var onCalloutCancel: (() -> Void)?

    private let keyAction: ZhuyinPhoneLayout.KeyAction
    private var repeatTimer: Timer?
    private var repeatHandler: (() -> Void)?
    private var calloutActive = false
    /// After a callout commit, ignore the following touchUpInside (would re-fire primary key e.g. 。).
    private var suppressNextTap = false

    init(label: String, action: ZhuyinPhoneLayout.KeyAction, style: Style) {
        self.keyAction = action
        super.init(frame: .zero)
        setTitle(label, for: .normal)
        setTitleColor(.black, for: .normal)
        let fontSize: CGFloat
        switch style {
        case .tone: fontSize = 26
        case .function: fontSize = label == "換行" ? 15 : 16
        case .zhuyin:
            if label.contains("/") {
                fontSize = 14
            } else if label.count >= 4 {
                fontSize = 20
            } else if label.count == 3 {
                fontSize = 22
            } else {
                fontSize = 24
            }
        }
        titleLabel?.font = .systemFont(ofSize: fontSize, weight: .semibold)
        titleLabel?.numberOfLines = style == .tone ? 1 : 2
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontSizeToFitWidth = true
        // Zhuyin initials/finals: prefer staying large; tones match peers at 26.
        titleLabel?.minimumScaleFactor = style == .zhuyin ? 0.75 : 0.65
        keyStyle = style
        applyChrome(traits: traitCollection)
        layer.cornerRadius = 7
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0.5
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    private var keyStyle: Style = .zhuyin

    func applyChrome(traits: UITraitCollection) {
        let fill: KeyboardChrome.KeyFillStyle
        switch keyStyle {
        case .zhuyin: fill = .zhuyin
        case .tone: fill = .tone
        case .function: fill = .function
        }
        backgroundColor = KeyboardChrome.keyFill(for: traits, style: fill)
        setTitleColor(KeyboardChrome.keyTitle(for: traits), for: .normal)
    }

    required init?(coder: NSCoder) { fatalError() }

    func enableRepeatDelete(_ handler: @escaping () -> Void) {
        repeatHandler = handler
        addTarget(self, action: #selector(touchDownRepeat), for: .touchDown)
        addTarget(self, action: #selector(touchUpRepeat), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    /// Attach callouts after init. Keys without callouts get no long-press gesture
    /// so hold-to-repeat (backspace) is not cancelled.
    func setCallouts(_ items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)]) {
        onLongPressCallout = items
        gestureRecognizers?
            .compactMap { $0 as? UILongPressGestureRecognizer }
            .forEach { removeGestureRecognizer($0) }
        guard !items.isEmpty else { return }
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))
        lp.minimumPressDuration = 0.35
        // Allow generous finger travel while holding — selection is relative, not absolute hit-testing.
        lp.allowableMovement = 120
        lp.cancelsTouchesInView = false
        addGestureRecognizer(lp)
    }

    @objc private func tapped() {
        if suppressNextTap {
            suppressNextTap = false
            return
        }
        guard !calloutActive else { return }
        // Backspace uses touchDown repeat path instead.
        guard repeatHandler == nil else { return }
        KeyboardHaptics.keyTap()
        onTap?(keyAction)
    }

    @objc private func longPressed(_ g: UILongPressGestureRecognizer) {
        let windowPoint = g.location(in: nil)
        switch g.state {
        case .began:
            guard !onLongPressCallout.isEmpty else { return }
            calloutActive = true
            onCalloutBegin?(onLongPressCallout)
            // Seed relative origin immediately.
            onCalloutMove?(windowPoint)
        case .changed:
            guard calloutActive else { return }
            onCalloutMove?(windowPoint)
        case .ended:
            if calloutActive {
                onCalloutEnd?()
                suppressNextTap = true
            }
            calloutActive = false
        case .cancelled, .failed:
            if calloutActive {
                onCalloutCancel?()
                suppressNextTap = true
            }
            calloutActive = false
        default:
            break
        }
    }

    @objc private func touchDownRepeat() {
        guard let handler = repeatHandler else { return }
        handler()
        repeatTimer?.invalidate()
        let delay = Timer(timeInterval: 0.4, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.repeatTimer?.invalidate()
            let fast = Timer(timeInterval: 0.07, repeats: true) { [weak self] _ in
                self?.repeatHandler?()
            }
            RunLoop.main.add(fast, forMode: .common)
            self.repeatTimer = fast
        }
        RunLoop.main.add(delay, forMode: .common)
        repeatTimer = delay
    }

    @objc private func touchUpRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}