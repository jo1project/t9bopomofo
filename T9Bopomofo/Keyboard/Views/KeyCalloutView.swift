import UIKit

/// Horizontal long-press callout bubble with slide-to-select (Hamster-style).
/// Scrolls when there are more punctuation items than fit on screen.
final class KeyCalloutView: UIView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var labels: [UILabel] = []
    private(set) var items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)] = []
    private(set) var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.borderColor = UIColor(white: 0.75, alpha: 1).cgColor
        layer.borderWidth = 0.5
        clipsToBounds = false

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)], selected: Int = 0) {
        self.items = items
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        labels = []
        for item in items {
            let lab = UILabel()
            lab.text = item.label
            lab.textAlignment = .center
            lab.font = .systemFont(ofSize: item.label.count <= 2 ? 26 : 20, weight: .semibold)
            lab.layer.cornerRadius = 8
            lab.clipsToBounds = true
            lab.translatesAutoresizingMaskIntoConstraints = false
            lab.widthAnchor.constraint(equalToConstant: 44).isActive = true
            lab.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(lab)
            labels.append(lab)
        }
        select(index: min(max(0, selected), max(0, items.count - 1)))
        setNeedsLayout()
        layoutIfNeeded()
        scrollSelectedIntoView(animated: false)
    }

    func select(index: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = min(max(0, index), items.count - 1)
        for (i, lab) in labels.enumerated() {
            if i == selectedIndex {
                lab.backgroundColor = UIColor.systemBlue
                lab.textColor = .white
            } else {
                lab.backgroundColor = .clear
                lab.textColor = .black
            }
        }
        scrollSelectedIntoView(animated: true)
    }

    func select(atLocationInCallout x: CGFloat) {
        guard !labels.isEmpty else { return }
        let contentX = x + scrollView.contentOffset.x - scrollView.frame.minX
        let idx = labels.enumerated().min(by: {
            abs($0.element.center.x - contentX) < abs($1.element.center.x - contentX)
        })?.offset ?? 0
        select(index: idx)
    }

    var selectedAction: ZhuyinPhoneLayout.KeyAction? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex].action
    }

    private func scrollSelectedIntoView(animated: Bool) {
        guard labels.indices.contains(selectedIndex) else { return }
        let lab = labels[selectedIndex]
        let target = lab.frame.insetBy(dx: -12, dy: 0)
        scrollView.scrollRectToVisible(target, animated: animated)
    }
}
