import UIKit

/// Horizontal tray of common punctuation (Hamster 。 callout behavior on tap).
final class PunctuationTrayView: UIView {
    var onPick: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let symbols = ["。", "，", "？", "！", "、", "…", "：", "；", "「", "」", "『", "』", "（", "）", "～", "@", "#", "—"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.9, alpha: 0.98)
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for s in symbols {
            let b = UIButton(type: .system)
            b.setTitle(s, for: .normal)
            b.setTitleColor(.black, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
            b.backgroundColor = .white
            b.layer.cornerRadius = 8
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
            let captured = s
            b.addAction(UIAction { [weak self] _ in
                self?.onPick?(captured)
            }, for: .touchUpInside)
            stack.addArrangedSubview(b)
            b.heightAnchor.constraint(equalToConstant: 40).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        }

        let close = UIButton(type: .system)
        close.setTitle("✕", for: .normal)
        close.setTitleColor(.darkGray, for: .normal)
        close.addAction(UIAction { [weak self] _ in self?.onDismiss?() }, for: .touchUpInside)
        stack.addArrangedSubview(close)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
