import UIKit
import ObjectiveC

final class CandidateBarView: UIView {
    var onSelect: ((Candidate) -> Void)?
    var onToggleExpand: (() -> Void)?
    var onDismissKeyboard: (() -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let preeditLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private var preeditMaxWidth: NSLayoutConstraint?
    private(set) var isExpanded = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        preeditLabel.font = .systemFont(ofSize: 12, weight: .medium)
        preeditLabel.textColor = .darkGray
        preeditLabel.translatesAutoresizingMaskIntoConstraints = false
        preeditLabel.lineBreakMode = .byTruncatingTail
        preeditLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        expandButton.setTitle("▼", for: .normal)
        expandButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        expandButton.setTitleColor(.darkGray, for: .normal)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        expandButton.addAction(UIAction { [weak self] _ in
            self?.onToggleExpand?()
        }, for: .touchUpInside)

        dismissButton.setTitle("↓", for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        dismissButton.setTitleColor(.darkGray, for: .normal)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.accessibilityLabel = "隱藏鍵盤"
        dismissButton.addAction(UIAction { [weak self] _ in
            self?.onDismissKeyboard?()
        }, for: .touchUpInside)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        addSubview(preeditLabel)
        addSubview(scroll)
        addSubview(expandButton)
        addSubview(dismissButton)

        let maxW = preeditLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
        preeditMaxWidth = maxW

        NSLayoutConstraint.activate([
            preeditLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            preeditLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            maxW,

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            dismissButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: 34),
            dismissButton.heightAnchor.constraint(equalToConstant: 36),

            expandButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -2),
            expandButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 34),
            expandButton.heightAnchor.constraint(equalToConstant: 36),

            scroll.leadingAnchor.constraint(equalTo: preeditLabel.trailingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor, constant: -2),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
        expandButton.setTitle(expanded ? "▲" : "▼", for: .normal)
    }

    func setCandidates(_ items: [Candidate], preedit: String, status: String = "") {
        if !preedit.isEmpty {
            preeditLabel.text = preedit
            preeditLabel.textColor = .darkGray
            preeditMaxWidth?.constant = 80
        } else if !status.isEmpty {
            preeditLabel.text = status
            preeditLabel.textColor = status.hasPrefix("LLM失敗") || status.contains("需開啟") || status.contains("未設定")
                ? .systemOrange
                : .systemBlue
            preeditMaxWidth?.constant = 150
        } else {
            preeditLabel.text = ""
            preeditLabel.textColor = .darkGray
            preeditMaxWidth?.constant = 80
        }

        expandButton.isEnabled = !items.isEmpty || !preedit.isEmpty
        expandButton.alpha = expandButton.isEnabled ? 1 : 0.35
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (idx, c) in items.enumerated() {
            let btn = UIButton(type: .system)
            if c.source == .llm {
                btn.setTitle("✦ \(c.text)", for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
                btn.setTitleColor(UIColor(red: 0.12, green: 0.35, blue: 0.55, alpha: 1), for: .normal)
                btn.backgroundColor = UIColor(red: 0.82, green: 0.91, blue: 1.0, alpha: 1)
                btn.layer.borderWidth = 1
                btn.layer.borderColor = UIColor(red: 0.45, green: 0.68, blue: 0.92, alpha: 1).cgColor
            } else {
                btn.setTitle(c.text, for: .normal)
                btn.titleLabel?.font = .systemFont(ofSize: 20, weight: idx == 0 ? .semibold : .regular)
                btn.setTitleColor(.black, for: .normal)
                btn.backgroundColor = UIColor.white.withAlphaComponent(0.75)
            }
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            btn.layer.cornerRadius = 8
            btn.addTarget(self, action: #selector(tap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
            objc_setAssociatedObject(btn, &Assoc.candidate, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
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
        backgroundColor = UIColor(white: 0.9, alpha: 0.98)
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
            let btn = UIButton(type: .system)
            if c.source == .llm {
                btn.setTitle("✦\(c.text)", for: .normal)
                btn.setTitleColor(UIColor(red: 0.12, green: 0.35, blue: 0.55, alpha: 1), for: .normal)
                btn.backgroundColor = UIColor(red: 0.82, green: 0.91, blue: 1.0, alpha: 1)
                btn.layer.borderWidth = 1
                btn.layer.borderColor = UIColor(red: 0.45, green: 0.68, blue: 0.92, alpha: 1).cgColor
                btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            } else {
                btn.setTitle(c.text, for: .normal)
                btn.setTitleColor(.black, for: .normal)
                btn.backgroundColor = .white
                btn.titleLabel?.font = .systemFont(ofSize: 20, weight: idx == 0 ? .semibold : .regular)
            }
            btn.layer.cornerRadius = 8
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
