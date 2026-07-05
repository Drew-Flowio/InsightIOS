import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    @State private var glow = false

    var body: some View {
        VStack(spacing: InsightSpacing.md) {
            ZStack {
                Circle()
                    .fill(InsightColors.accentSoft)
                    .frame(width: 72, height: 72)
                    .blur(radius: glow ? 8 : 2)

                Circle()
                    .strokeBorder(InsightTheme.accentGradient, lineWidth: 1.5)
                    .frame(width: 56, height: 56)
                    .shadow(color: InsightColors.accentGlow, radius: glow ? 16 : 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(InsightTheme.accentGradient)
            }

            Text(title)
                .font(InsightTypography.headline())
                .foregroundStyle(InsightColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(InsightSpacing.xl)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

#Preview {
    EmptyStateView(
        title: ChatPreviewData.welcomeTitle,
        subtitle: ChatPreviewData.welcomeSubtitle
    )
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
