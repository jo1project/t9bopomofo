import UIKit
import ObjectiveC

final class CandidateBarView: UIView {
    var onSelect: ((Candidate) -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let preeditLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        preeditLabel.font = .systemFont(ofSize: 12, weight: .medium)
        preeditLabel.textColor = .darkGray
        preeditLabel.translatesAutoresizingMaskIntoConstraints = false

        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        addSubview(preeditLabel)
        addSubview(scroll)

        NSLayoutConstraint.activate([
            preeditLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            preeditLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            preeditLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 72),

            scroll.leadingAnchor.constraint(equalTo: preeditLabel.trailingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
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

    func setCandidates(_ items: [Candidate], preedit: String) {
        preeditLabel.text = preedit
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for (idx, c) in items.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(c.text, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: idx == 0 ? .semibold : .regular)
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.7)
            btn.layer.cornerRadius = 8
            btn.tag = idx
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

private enum Assoc {
    static var candidate: UInt8 = 0
}
