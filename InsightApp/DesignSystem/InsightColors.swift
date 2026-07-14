import SwiftUI

enum InsightColors {
    // MARK: - Backgrounds (deep black → midnight navy)

    static let background = Color(red: 0.02, green: 0.025, blue: 0.045)
    static let backgroundGradientTop = Color(red: 0.04, green: 0.055, blue: 0.095)
    static let backgroundGradientBottom = Color(red: 0.015, green: 0.018, blue: 0.028)

    static let surface = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let surfaceElevated = Color(red: 0.09, green: 0.11, blue: 0.15)
    static let surfaceOverlay = Color.white.opacity(0.035)

    // MARK: - Text (moonlight hierarchy)

    static let textPrimary = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let textSecondary = Color(red: 0.62, green: 0.68, blue: 0.76)
    static let textTertiary = Color(red: 0.42, green: 0.48, blue: 0.56)

    // MARK: - Primary accent (moonlight white)

    static let accent = Color(red: 0.92, green: 0.945, blue: 0.98)
    static let accentBright = Color(red: 0.98, green: 0.99, blue: 1.0)
    static let accentSoft = Color(red: 0.55, green: 0.68, blue: 0.92).opacity(0.14)
    static let accentGlow = Color(red: 0.45, green: 0.62, blue: 0.95).opacity(0.32)

    // MARK: - Cool blue glow (active states)

    static let glowBlue = Color(red: 0.28, green: 0.48, blue: 0.88).opacity(0.14)
    static let glowBlueStrong = Color(red: 0.35, green: 0.58, blue: 0.95)
    static let glowNavy = Color(red: 0.12, green: 0.22, blue: 0.42).opacity(0.35)

    // MARK: - Warm amber (sparing tent accent)

    static let amber = Color(red: 0.86, green: 0.62, blue: 0.28)
    static let amberSoft = Color(red: 0.86, green: 0.62, blue: 0.28).opacity(0.16)
    static let amberGlow = Color(red: 0.92, green: 0.68, blue: 0.32).opacity(0.28)

    // MARK: - Semantic runtime states

    static let listening = Color(red: 0.42, green: 0.62, blue: 0.98)
    static let thinking = Color(red: 0.72, green: 0.82, blue: 0.98)
    static let success = Color(red: 0.38, green: 0.78, blue: 0.62)
    static let border = Color.white.opacity(0.07)
    static let borderStrong = Color.white.opacity(0.12)

    // MARK: - Bubbles

    static let userBubbleStart = Color(red: 0.14, green: 0.20, blue: 0.32)
    static let userBubbleEnd = Color(red: 0.10, green: 0.14, blue: 0.24)
    static let assistantBubble = Color(red: 0.08, green: 0.10, blue: 0.14)
}
