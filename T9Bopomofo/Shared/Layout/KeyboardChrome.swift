import UIKit

enum KeyboardHaptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let select = UISelectionFeedbackGenerator()

    static func keyTap() {
        guard AppSettings.shared.hapticsEnabled else { return }
        light.impactOccurred(intensity: 0.7)
    }

    static func calloutTick() {
        guard AppSettings.shared.hapticsEnabled else { return }
        select.selectionChanged()
    }

    static func commit() {
        guard AppSettings.shared.hapticsEnabled else { return }
        medium.impactOccurred(intensity: 0.85)
    }
}

enum KeyboardChrome {
    static func background(for traits: UITraitCollection) -> UIColor {
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.18, alpha: 1)
            : UIColor(white: 0.78, alpha: 1)
    }

    static func keyFill(for traits: UITraitCollection, style: KeyFillStyle) -> UIColor {
        let dark = traits.userInterfaceStyle == .dark
        switch style {
        case .zhuyin:
            return dark ? UIColor(white: 0.32, alpha: 1) : .white
        case .tone:
            return dark ? UIColor(white: 0.28, alpha: 1) : UIColor(white: 0.92, alpha: 1)
        case .function:
            return dark ? UIColor(white: 0.24, alpha: 1) : UIColor(white: 0.72, alpha: 1)
        }
    }

    static func keyTitle(for traits: UITraitCollection) -> UIColor {
        traits.userInterfaceStyle == .dark ? .white : .black
    }

    enum KeyFillStyle {
        case zhuyin, tone, function
    }
}
