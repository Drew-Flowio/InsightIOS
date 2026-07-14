import SwiftUI

struct InsightIconButtonStyle: ButtonStyle {
    var tint: Color = InsightColors.textSecondary
    var background: Color = InsightColors.surfaceElevated
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isProminent ? InsightColors.background : tint)
            .frame(width: InsightSpacing.minTouchTarget, height: InsightSpacing.minTouchTarget)
            .background {
                Circle()
                    .fill(isProminent ? AnyShapeStyle(InsightTheme.accentGradient) : AnyShapeStyle(background))
                    .overlay {
                        Circle()
                            .strokeBorder(
                                isProminent ? InsightColors.accent.opacity(0.35) : InsightColors.border,
                                lineWidth: 1
                            )
                    }
                    .shadow(color: isProminent ? InsightColors.accentGlow : .clear, radius: 10, y: 3)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct InsightPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InsightTypography.bodyMedium())
            .foregroundStyle(InsightColors.background)
            .padding(.horizontal, InsightSpacing.lg)
            .padding(.vertical, InsightSpacing.sm)
            .background {
                Capsule()
                    .fill(InsightTheme.accentGradient)
                    .overlay {
                        Capsule()
                            .strokeBorder(InsightColors.accentBright.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: InsightColors.accentGlow, radius: 12, y: 4)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct InsightSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InsightTypography.caption())
            .foregroundStyle(InsightColors.textPrimary)
            .padding(.horizontal, InsightSpacing.md)
            .padding(.vertical, InsightSpacing.xs)
            .background {
                Capsule()
                    .fill(InsightColors.surfaceElevated)
                    .overlay {
                        Capsule()
                            .strokeBorder(InsightColors.borderStrong, lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
