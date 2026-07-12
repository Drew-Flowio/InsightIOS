import SwiftUI
import InsightCore

struct PhotoAnalysisSourceBadge: View {
    let source: VisionAnalysisSource

    var body: some View {
        HStack(spacing: InsightSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
            Text(source.customerAnalysisLabel)
                .font(InsightTypography.micro())
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, InsightSpacing.sm)
        .padding(.vertical, InsightSpacing.xxs)
        .background {
            Capsule(style: .continuous)
                .fill(InsightColors.surfaceElevated.opacity(0.75))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(InsightColors.border, lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Photo analysis: \(source.customerAnalysisLabel)")
    }

    private var iconName: String {
        switch source {
        case .ocrAndVlm:
            "eye.fill"
        case .ocrOnly, .vlmUnavailable, .vlmFailed:
            "text.viewfinder"
        }
    }

    private var foregroundColor: Color {
        switch source {
        case .ocrAndVlm:
            InsightColors.accent
        case .ocrOnly, .vlmUnavailable, .vlmFailed:
            InsightColors.textSecondary
        }
    }
}

#Preview {
    VStack(spacing: InsightSpacing.sm) {
        PhotoAnalysisSourceBadge(source: .ocrOnly)
        PhotoAnalysisSourceBadge(source: .ocrAndVlm)
    }
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
