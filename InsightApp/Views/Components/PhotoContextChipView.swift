import SwiftUI

struct PhotoContextChipView: View {
    let caption: String
    let onClear: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: InsightSpacing.sm) {
            Image(systemName: "viewfinder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InsightColors.accent)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Active photo context")
                    .font(InsightTypography.micro())
                    .foregroundStyle(InsightColors.accent)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(caption)
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InsightColors.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(InsightColors.surfaceOverlay))
            }
            .buttonStyle(.plain)
        }
        .padding(InsightSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                .fill(InsightColors.accentSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                        .strokeBorder(InsightColors.accent.opacity(0.25), lineWidth: 1)
                }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    PhotoContextChipView(
        caption: "A stainless steel electric kettle on a kitchen counter.",
        onClear: {}
    )
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
