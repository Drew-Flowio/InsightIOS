import SwiftUI

struct InsightIconButtonStyle: ButtonStyle {
    var tint: Color = InsightColors.textSecondary
    var background: Color = InsightColors.surfaceElevated
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isProminent ? Color.black.opacity(0.85) : tint)
            .frame(width: InsightSpacing.minTouchTarget, height: InsightSpacing.minTouchTarget)
            .background {
                Circle()
                    .fill(isProminent ? AnyShapeStyle(InsightTheme.accentGradient) : AnyShapeStyle(background))
                    .overlay {
                        Circle()
                            .strokeBorder(InsightColors.border, lineWidth: isProminent ? 0 : 1)
                    }
                    .shadow(color: isProminent ? InsightColors.accentGlow : .clear, radius: 12, y: 4)
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct InsightPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(InsightTypography.bodyMedium())
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, InsightSpacing.lg)
            .padding(.vertical, InsightSpacing.sm)
            .background {
                Capsule()
                    .fill(InsightTheme.accentGradient)
                    .shadow(color: InsightColors.accentGlow, radius: 14, y: 4)
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
