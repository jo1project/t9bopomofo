import UIKit
import ObjectiveC

final class CandidateBarView: UIView {
    var onSelect: ((Candidate) -> Void)?
    var onToggleExpand: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let preeditContainer = UIView()
    private let preeditLabel = UILabel()
    private let divider = UIView()
    private let expandButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private var preeditMaxWidth: NSLayoutConstraint?
    private(set) var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        preeditLabel.font = .systemFont(ofSize: 12, weight: .medium)
        preeditLabel.translatesAutoresizingMaskIntoConstraints = false
        preeditLabel.lineBreakMode = .byTruncatingTail
        preeditLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        preeditLabel.textAlignment = .center

        // Chip around preeditLabel: visually marks "this is your raw input", distinct
        // from the candidate pills to its right.
        preeditContainer.translatesAutoresizingMaskIntoConstraints = false
        preeditContainer.layer.cornerRadius = 8
        preeditContainer.addSubview(preeditLabel)

        divider.translatesAutoresizingMaskIntoConstraints = false

        expandButton.setTitle("▼", for: .normal)
        expandButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.addAction(UIAction { [weak self] _ in
            self?.onToggleExpand?()
        }, for: .touchUpInside)

        dismissButton.setTitle("↓", for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.accessibilityLabel = "隱藏鍵盤"
        dismissButton.addAction(UIAction { [weak self] _ in
            self?.onDismissKeyboard?()
        }, for: .touchUpInside)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        addSubview(preeditContainer)
        addSubview(divider)
        addSubview(scroll)
        addSubview(expandButton)
        addSubview(dismissButton)

        let maxW = preeditContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 88)
        preeditMaxWidth = maxW

        NSLayoutConstraint.activate([
            preeditContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            preeditContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            preeditContainer.heightAnchor.constraint(equalToConstant: 28),
            maxW,

            preeditLabel.leadingAnchor.constraint(equalTo: preeditContainer.leadingAnchor, constant: 8),
            preeditLabel.trailingAnchor.constraint(equalTo: preeditContainer.trailingAnchor, constant: -8),
            preeditLabel.topAnchor.constraint(equalTo: preeditContainer.topAnchor),
            preeditLabel.bottomAnchor.constraint(equalTo: preeditContainer.bottomAnchor),

            divider.leadingAnchor.constraint(equalTo: preeditContainer.trailingAnchor, constant: 6),
            divider.centerYAnchor.constraint(equalTo: centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 22),

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 34),
            dismissButton.heightAnchor.constraint(equalToConstant: 36),

            expandButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -2),
            expandButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 34),
            expandButton.heightAnchor.constraint(equalToConstant: 36),

            scroll.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -2),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])

        applyChrome()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChrome()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func applyChrome() {
        let dark = traitCollection.userInterfaceStyle == .dark
        // Same tone as the keyboard grid below so the bar reads as one continuous
        // surface instead of a separate strip.
        backgroundColor = KeyboardChrome.background(for: traitCollection)
        preeditContainer.backgroundColor = UIColor(white: dark ? 0.30 : 0.68, alpha: 1)
        preeditLabel.textColor = dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        divider.backgroundColor = dark ? UIColor.white.withAlphaComponent(0.15) : UIColor.black.withAlphaComponent(0.15)
        let buttonTint: UIColor = dark ? .white : .darkGray
        expandButton.setTitleColor(buttonTint, for: .normal)
        dismissButton.setTitleColor(buttonTint, for: .normal)
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        expandButton.setTitle(expanded ? "▲" : "▼", for: .normal)
    }

    func setCandidates(_ items: [Candidate], preedit: String, status: String = "") {
        let dark = traitCollection.userInterfaceStyle == .dark
        if !preedit.isEmpty {
            preeditLabel.text = preedit
            preeditLabel.textColor = dark ? UIColor(white: 0.92, alpha: 1) : UIColor(white: 0.12, alpha: 1)
            preeditMaxWidth?.constant = 88
        } else if !status.isEmpty {
            preeditLabel.text = status
            preeditLabel.textColor = status.hasPrefix("LLM失敗") || status.contains("需開啟") || status.contains("未設定")
                ? .systemOrange
                : .systemBlue
            preeditMaxWidth?.constant = 150
        } else {
            preeditLabel.text = ""
            preeditMaxWidth?.constant = 88
        }
        preeditContainer.isHidden = preeditLabel.text?.isEmpty ?? true
        divider.isHidden = preeditContainer.isHidden

        expandButton.isEnabled = !items.isEmpty || !preedit.isEmpty
        expandButton.alpha = expandButton.isEnabled ? 1 : 0.35
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (idx, c) in items.enumerated() {
            let btn = CandidateBarView.makePillButton(c, isTop: idx == 0, traits: traitCollection)
            btn.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
            objc_setAssociatedObject(btn, &Assoc.candidate, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Shared pill styling for both the scrolling bar and the expanded grid panel.
    static func makePillButton(_ c: Candidate, isTop: Bool, traits: UITraitCollection) -> UIButton {
        let dark = traits.userInterfaceStyle == .dark
        let btn = UIButton(type: .system)
        if c.source == .llm {
            btn.setTitle("✦ \(c.text)", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
            btn.setTitleColor(dark ? UIColor(red: 0.65, green: 0.85, blue: 1.0, alpha: 1) : UIColor(red: 0.12, green: 0.35, blue: 0.55, alpha: 1), for: .normal)
            btn.backgroundColor = dark ? UIColor(red: 0.14, green: 0.24, blue: 0.34, alpha: 1) : UIColor(red: 0.82, green: 0.91, blue: 1.0, alpha: 1)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor(red: 0.45, green: 0.68, blue: 0.92, alpha: 1).cgColor
        } else {
            btn.setTitle(c.text, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 20, weight: isTop ? .semibold : .regular)
            btn.setTitleColor(KeyboardChrome.keyTitle(for: traits), for: .normal)
            btn.backgroundColor = KeyboardChrome.keyFill(for: traits, style: .zhuyin)
            btn.layer.borderWidth = isTop ? 1.5 : 1
            btn.layer.borderColor = (isTop
                ? KeyboardChrome.accent
                : (dark ? UIColor.white.withAlphaComponent(0.12) : UIColor.black.withAlphaComponent(0.08))
            ).cgColor
        }
        btn.contentEdgeInsets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        btn.layer.cornerRadius = 16 // pill: fully rounded against the ~32pt tall button
        KeyboardChrome.applyKeyShadow(btn.layer)
        return btn
    }

    @objc private func tap(_ sender: UIButton) {
        if let c = objc_getAssociatedObject(sender, &Assoc.candidate) as? Candidate {
            onSelect?(c)
        }
    }
}

/// Full panel of candidates (grid) shown when bar is expanded.
final class CandidatePanelView: UIView {
    var onSelect: ((Candidate) -> Void)?
    var onClose: (() -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyChrome()
        layer.cornerRadius = 10

        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyChrome()
    }

    private func applyChrome() {
        let dark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = dark ? UIColor(white: 0.14, alpha: 0.98) : UIColor(white: 0.9, alpha: 0.98)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setCandidates(_ items: [Candidate]) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let cols = 6
        var row: UIStackView?
        for (idx, c) in items.enumerated() {
            if idx % cols == 0 {
                row = UIStackView()
                row?.axis = .horizontal
                row?.spacing = 6
                row?.distribution = .fillEqually
                stack.addArrangedSubview(row!)
            }
            let btn = CandidateBarView.makePillButton(c, isTop: idx == 0, traits: traitCollection)
            btn.layer.cornerRadius = 8 // grid cells stay rounded rects, not pills
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            btn.addAction(UIAction { [weak self] _ in self?.onSelect?(c) }, for: .touchUpInside)
            row?.addArrangedSubview(btn)
        }
        // pad last row
        if let row {
            let count = row.arrangedSubviews.count
            if count < cols {
                for _ in count..<cols {
                    row.addArrangedSubview(UIView())
                }
            }
        }
    }
}
private enum Assoc {
    static var candidate: UInt8 = 0
}
