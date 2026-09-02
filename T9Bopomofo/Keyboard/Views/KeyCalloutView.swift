import UIKit

/// Horizontal long-press callout bubble with **in-place relative** slide-to-select.
/// Finger stays near the key; small left/right movement changes the highlighted option.
final class KeyCalloutView: UIView {
    private let stack = UIStackView()
    private var labels: [UILabel] = []
    private(set) var items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)] = []
    private(set) var selectedIndex: Int = 0

    /// Finger X when long-press began (window coords). Selection uses delta from this.
    private var originWindowX: CGFloat?
    /// Pixels of horizontal travel per option step.
    private let pixelsPerStep: CGFloat = 26

    var onSelectionChanged: ((Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.22, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        }
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5

        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(items: [(label: String, action: ZhuyinPhoneLayout.KeyAction)], selected: Int = 0) {
        self.items = items
        originWindowX = nil
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
            lab.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            lab.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(lab)
            labels.append(lab)
        }
        select(index: min(max(0, selected), max(0, items.count - 1)), haptic: false)
    }

    func beginTracking(windowX: CGFloat) {
        originWindowX = windowX
    }

    func select(index: Int, haptic: Bool = true) {
        guard !items.isEmpty else { return }
        let next = min(max(0, index), items.count - 1)
        let changed = next != selectedIndex
        selectedIndex = next
        let dark = traitCollection.userInterfaceStyle == .dark
        for (i, lab) in labels.enumerated() {
            if i == selectedIndex {
                lab.backgroundColor = .systemBlue
                lab.textColor = .white
            } else {
                lab.backgroundColor = .clear
                lab.textColor = dark ? .white : .black
            }
        }
        if changed && haptic {
            onSelectionChanged?(selectedIndex)
            KeyboardHaptics.calloutTick()
        }
    }

    /// Relative slide: small movement near the key cycles options (no need to reach each glyph).
    func select(trackingWindowX x: CGFloat) {
        guard !labels.isEmpty else { return }
        let origin = originWindowX ?? x
        if originWindowX == nil { originWindowX = x }
        let delta = x - origin
        let idx = Int((delta / pixelsPerStep).rounded()) + initialIndexForRelative
        select(index: idx)
    }

    /// Absolute mapping kept for callers that still pass callout-local X (unused by new path).
    func select(atLocationInCallout x: CGFloat) {
        guard !labels.isEmpty else { return }
        let idx = labels.enumerated().min(by: {
            abs($0.element.center.x - x) < abs($1.element.center.x - x)
        })?.offset ?? 0
        select(index: idx)
    }

    /// Base index when relative tracking starts (often 0; punctuation may prefer mid).
    private var initialIndexForRelative: Int = 0

    func setInitialIndex(_ index: Int) {
        initialIndexForRelative = min(max(0, index), max(0, items.count - 1))
        select(index: initialIndexForRelative, haptic: false)
    }

    var selectedAction: ZhuyinPhoneLayout.KeyAction? {
        guard items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex].action
    }
}
