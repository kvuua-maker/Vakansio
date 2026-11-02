import SwiftUI
import UIKit
import Foundation

// MARK: - Design tokens

enum VK {
    // Brand
    static let brand = Color(hex: 0x0066CC)
    static let brandDark = Color(hex: 0x004B99)
    static let brandDeep = Color(hex: 0x003A78)
    static let brandSoft = Color(hex: 0xE6F0FA)

    // Semantic
    static let success = Color(hex: 0x34C759)
    static let warning = Color(hex: 0xFF9500)
    static let danger = Color(hex: 0xFF3B30)

    // Layout
    static let radius: CGFloat = 16
    static let spacing: CGFloat = 16

    // Surfaces (adaptive for dark mode)
    static let screen = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let surface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let elevated = Color(uiColor: .systemBackground)

    // Text
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)
    static let hairline = Color(uiColor: .separator).opacity(0.4)

    // Gradients
    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x0A7BEA), Color(hex: 0x00408F)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x0066CC), Color(hex: 0x004B99)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let premiumGradient = LinearGradient(
        colors: [Color(hex: 0x1B2A4A), Color(hex: 0x0066CC)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Font {
    static let vkDisplay = Font.system(size: 30, weight: .bold)
    static let vkTitle = Font.system(size: 22, weight: .bold)
    static let vkHeadline = Font.system(size: 17, weight: .semibold)
    static let vkBody = Font.system(size: 16, weight: .regular)
    static let vkBodyMedium = Font.system(size: 16, weight: .medium)
    static let vkCallout = Font.system(size: 15, weight: .regular)
    static let vkCaption = Font.system(size: 13, weight: .regular)
    static let vkCaptionBold = Font.system(size: 13, weight: .semibold)
    static let vkMicro = Font.system(size: 11, weight: .medium)
    static let vkNumber = Font.system(size: 24, weight: .bold, design: .rounded)
}
