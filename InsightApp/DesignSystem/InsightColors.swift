import SwiftUI

enum InsightColors {
    // MARK: - Backgrounds

    static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let backgroundGradientTop = Color(red: 0.07, green: 0.06, blue: 0.10)
    static let backgroundGradientBottom = Color(red: 0.03, green: 0.03, blue: 0.04)

    static let surface = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let surfaceElevated = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let surfaceOverlay = Color.white.opacity(0.04)

    // MARK: - Text

    static let textPrimary = Color(red: 0.96, green: 0.96, blue: 0.98)
    static let textSecondary = Color(red: 0.62, green: 0.62, blue: 0.68)
    static let textTertiary = Color(red: 0.42, green: 0.42, blue: 0.48)

    // MARK: - Accent (warm amber-gold)

    static let accent = Color(red: 0.93, green: 0.72, blue: 0.38)
    static let accentBright = Color(red: 1.0, green: 0.82, blue: 0.48)
    static let accentSoft = Color(red: 0.93, green: 0.72, blue: 0.38).opacity(0.18)
    static let accentGlow = Color(red: 0.93, green: 0.72, blue: 0.38).opacity(0.35)

    // MARK: - Secondary accent (cool glow for depth)

    static let glowBlue = Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.12)
    static let glowPurple = Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.08)

    // MARK: - Semantic

    static let listening = Color(red: 0.95, green: 0.38, blue: 0.38)
    static let thinking = Color(red: 0.93, green: 0.72, blue: 0.38)
    static let success = Color(red: 0.35, green: 0.82, blue: 0.58)
    static let border = Color.white.opacity(0.08)
    static let borderStrong = Color.white.opacity(0.14)

    // MARK: - Bubbles

    static let userBubbleStart = Color(red: 0.85, green: 0.58, blue: 0.22)
    static let userBubbleEnd = Color(red: 0.72, green: 0.42, blue: 0.18)
    static let assistantBubble = Color(red: 0.12, green: 0.12, blue: 0.15)
}
