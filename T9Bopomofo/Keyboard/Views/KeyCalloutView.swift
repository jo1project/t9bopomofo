import UIKit

/// Long-press callout bubble with slide-to-select.
/// Short lists stay horizontal; longer lists (e.g. punctuation) use a vertical scroller.
/// Vertical lists put the default (first) item at the bottom, nearest the key.
final class KeyCalloutView: UIView {
    enum Axis {
        case horizontal
        case vertical

        static func preferred(forCount count: Int) -> Axis {
            count >= 6 ? .vertical : .horizontal
        }
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var labels: [UILabel] = []
    /// Parallel to `labels`: original index into `items`.
    private var labelItemIndices: [Int] = []
    private var axis: Axis = .horizontal
    private var widthConstraints: [NSLayoutConstraint] = []
    private var heightConstraints: [NSLayoutConstraint] = []

    private(set) var items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)] = []
    private(set) var selectedIndex: Int = 0

    static let itemSide: CGFloat = 40
    static let chrome: CGFloat = 8

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
        scrollView.showsVerticalScrollIndicator = true
        scrollView.indicatorStyle = .black
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

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
        ])
        widthConstraints = [
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ]
        heightConstraints = [
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ]
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(
        items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)],
        selected: Int = 0,
        axis: Axis? = nil
    ) {
        self.items = items
        self.axis = axis ?? Axis.preferred(forCount: items.count)

        NSLayoutConstraint.deactivate(widthConstraints + heightConstraints)
        switch self.axis {
        case .horizontal:
            stack.axis = .horizontal
            scrollView.alwaysBounceHorizontal = items.count > 4
            scrollView.alwaysBounceVertical = false
            scrollView.showsVerticalScrollIndicator = false
            NSLayoutConstraint.activate(heightConstraints)
        case .vertical:
            stack.axis = .vertical
            scrollView.alwaysBounceHorizontal = false
            scrollView.alwaysBounceVertical = true
            scrollView.showsVerticalScrollIndicator = true
            NSLayoutConstraint.activate(widthConstraints)
        }

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        labels = []
        labelItemIndices = []

        // Vertical: reverse so first item sits at the bottom (nearest the key).
        let displayOrder: [(itemIndex: Int, item: (label: String, action: ZhuyinPhoneLayout.KeyAction))] = {
            switch self.axis {
            case .horizontal:
                return items.enumerated().map { ($0.offset, $0.element) }
            case .vertical:
                return items.enumerated().reversed().map { ($0.offset, $0.element) }
            }
        }()

        for entry in displayOrder {
            let lab = UILabel()
            lab.text = entry.item.label
            lab.textAlignment = .center
            lab.font = .systemFont(ofSize: entry.item.label.count <= 2 ? 24 : 18, weight: .semibold)
            lab.layer.cornerRadius = 8
            lab.clipsToBounds = true
            lab.translatesAutoresizingMaskIntoConstraints = false
            lab.widthAnchor.constraint(equalToConstant: Self.itemSide).isActive = true
            lab.heightAnchor.constraint(equalToConstant: Self.itemSide).isActive = true
            stack.addArrangedSubview(lab)
            labels.append(lab)
            labelItemIndices.append(entry.itemIndex)
        }

        select(index: min(max(0, selected), max(0, items.count - 1)), scroll: false)
        setNeedsLayout()
        layoutIfNeeded()
        // Start scrolled so the default (bottom) item is visible without jumping selection.
        if self.axis == .vertical {
            scrollSelectedIntoView(animated: false)
        }
    }

    /// Preferred size for the bubble given max bounds.
    func preferredSize(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let side = Self.itemSide
        let chrome = Self.chrome
        switch axis {
        case .horizontal:
            let contentW = CGFloat(items.count) * side + chrome
            return CGSize(
                width: min(max(56, contentW), maxWidth),
                height: side + chrome
            )
        case .vertical:
            let contentH = CGFloat(items.count) * side + chrome
            // Show ~6 rows; scroll for the rest.
            let visibleCap = side * 6 + chrome
            return CGSize(
                width: side + chrome,
                height: min(max(56, contentH), min(maxHeight, visibleCap))
            )
        }
    }

    func select(index: Int, scroll: Bool = true) {
        guard !items.isEmpty else { return }
        let next = min(max(0, index), items.count - 1)
        selectedIndex = next
        for (i, lab) in labels.enumerated() {
            let itemIdx = labelItemIndices[i]
            if itemIdx == selectedIndex {
                lab.backgroundColor = UIColor.systemBlue
                lab.textColor = .white
            } else {
                lab.backgroundColor = .clear
                lab.textColor = .black
            }
        }
        if scroll {
            scrollSelectedIntoView(animated: true)
        }
    }

    /// Update selection from a point in callout coordinates.
    /// Returns false if the point is outside the bubble (caller should keep prior selection).
    @discardableResult
    func select(atLocationInCallout point: CGPoint) -> Bool {
        guard !labels.isEmpty else { return false }
        let inset = bounds.insetBy(dx: -12, dy: -12)
        guard inset.contains(point) else { return false }

        let labelIndex: Int
        switch axis {
        case .horizontal:
            let contentX = point.x + scrollView.contentOffset.x - scrollView.frame.minX
            labelIndex = labels.enumerated().min(by: {
                abs($0.element.center.x - contentX) < abs($1.element.center.x - contentX)
            })?.offset ?? 0
        case .vertical:
            let contentY = point.y + scrollView.contentOffset.y - scrollView.frame.minY
            labelIndex = labels.enumerated().min(by: {
                abs($0.element.center.y - contentY) < abs($1.element.center.y - contentY)
            })?.offset ?? 0
        }
        guard labels.indices.contains(labelIndex) else { return false }
        select(index: labelItemIndices[labelIndex])
        return true
    }

    var selectedAction: ZhuyinPhoneLayout.KeyAction? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex].action
    }

    private func scrollSelectedIntoView(animated: Bool) {
        guard let labelIdx = labelItemIndices.firstIndex(of: selectedIndex),
              labels.indices.contains(labelIdx) else { return }
        let lab = labels[labelIdx]
        let target: CGRect
        switch axis {
        case .horizontal:
            target = lab.frame.insetBy(dx: -8, dy: 0)
        case .vertical:
            target = lab.frame.insetBy(dx: 0, dy: -8)
        }
        scrollView.scrollRectToVisible(target, animated: animated)
    }
}
