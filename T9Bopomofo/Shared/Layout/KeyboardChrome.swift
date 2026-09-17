import UIKit
import AudioToolbox

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

enum KeyboardSounds {
    static func keyTap() {
        guard AppSettings.shared.soundsEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    static func delete() {
        guard AppSettings.shared.soundsEnabled else { return }
        AudioServicesPlaySystemSound(1155)
    }

    static func commit() {
        guard AppSettings.shared.soundsEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
}

enum KeyboardChrome {
    /// Brand accent (orange) — used sparingly for action keys / highlights.
    static let accent = UIColor.systemOrange

    // MARK: - Shared row layout (kept identical across zhuyin/English/symbol
    // keyboards so switching between them doesn't visibly jump).
    static let rowSpacing: CGFloat = 4
    static let keySpacing: CGFloat = 4
    static let edgeInset: CGFloat = 2

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
            return dark ? accent.withAlphaComponent(0.28) : accent.withAlphaComponent(0.16)
        case .function:
            return dark ? UIColor(white: 0.10, alpha: 1) : UIColor(white: 0.60, alpha: 1)
        case .action:
            return accent
        }
    }

    static func keyTitle(for traits: UITraitCollection, style: KeyFillStyle = .zhuyin) -> UIColor {
        let dark = traits.userInterfaceStyle == .dark
        switch style {
        case .tone:
            return dark ? accent : UIColor(red: 0.62, green: 0.28, blue: 0.0, alpha: 1)
        case .action:
            return .white
        case .zhuyin, .function:
            return dark ? .white : .black
        }
    }

    /// Subtle "pressable" shadow — apply to every key layer (zhuyin/English/symbol) so
    /// they read as raised keys instead of flat color rectangles.
    static func applyKeyShadow(_ layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.16
        layer.shadowOffset = CGSize(width: 0, height: 1.5)
        layer.shadowRadius = 1.5
        layer.masksToBounds = false
    }

    enum KeyFillStyle {
        case zhuyin, tone, function, action
    }
}
