import SwiftUI
import UIKit

enum WishTheme {
    static let background = adaptive(light: 0xF4EFE6, dark: 0x14110F)
    static let card = adaptive(light: 0xFFFCF7, dark: 0x221E1A)
    static let ink = adaptive(light: 0x1C1916, dark: 0xF6F1EA)
    static let secondary = adaptive(light: 0x5E564E, dark: 0xC8BBAE)
    static let line = adaptive(light: 0xE4DACE, dark: 0x3A332C)
    static let track = adaptive(light: 0xE7DDD0, dark: 0x3A332C)
    static let seal = adaptive(light: 0x9E3D22, dark: 0xE28A5A)
    static let onSeal = adaptive(light: 0xFFF8F2, dark: 0x1C1916)
    static let sage = adaptive(light: 0x1F6B52, dark: 0x8ED4B8)
    static let danger = adaptive(light: 0x8E2E24, dark: 0xFF9B8E)

    static let chartPalette: [Color] = [
        Color(hex: 0xC65A3A),
        Color(hex: 0x2F7D72),
        Color(hex: 0xC4922A),
        Color(hex: 0xA85A6A),
        Color(hex: 0x4E6E8A),
        Color(hex: 0x7A6E62),
        Color(hex: 0x8A5A3A),
        Color(hex: 0x3E6B4F)
    ]

    static func categoryColor(_ category: WishExpenseCategory) -> Color {
        switch category {
        case .food: Color(hex: 0xC65A3A)
        case .transport: Color(hex: 0x2F7D72)
        case .shopping: Color(hex: 0xC4922A)
        case .entertainment: Color(hex: 0xA85A6A)
        case .housing: Color(hex: 0x4E6E8A)
        case .other: Color(hex: 0x7A6E62)
        }
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            uiColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static func uiColor(hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    static func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        let paper = uiColor(hex: 0xF4EFE6)
        let dark = uiColor(hex: 0x14110F)
        appearance.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : paper
        }
        let normal = uiColor(hex: 0x8A7D72)
        let selected = uiColor(hex: 0x9E3D22)
        let darkNormal = uiColor(hex: 0xB3A496)
        let darkSelected = uiColor(hex: 0xE28A5A)
        for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? darkNormal : normal
            }
            item.normal.titleTextAttributes = [.foregroundColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? darkNormal : normal
            }]
            item.selected.iconColor = UIColor { traits in
                traits.userInterfaceStyle == .dark ? darkSelected : selected
            }
            item.selected.titleTextAttributes = [.foregroundColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? darkSelected : selected
            }]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum WishHaptics {
    static func tap() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private static var isEnabled: Bool {
        let key = WishPreferenceKey.haptics
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
