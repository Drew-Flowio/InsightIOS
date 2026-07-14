import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    @State private var glow = false

    var body: some View {
        VStack(spacing: InsightSpacing.lg) {
            OGMBrandMark(style: .staticMark, size: 48)
                .opacity(glow ? 1 : 0.88)

            VStack(spacing: InsightSpacing.sm) {
                Text(title)
                    .font(InsightTypography.headline())
                    .foregroundStyle(InsightColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .tracking(0.3)

                Text(subtitle)
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .lineSpacing(3)
            }
        }
        .padding(InsightSpacing.xl)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
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
