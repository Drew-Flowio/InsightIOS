import SwiftUI
import InsightCore

struct LocationContextChipView: View {
    let caption: String
    let onClear: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: InsightSpacing.sm) {
            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(InsightColors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Location for this question")
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
                .fill(InsightColors.surfaceElevated.opacity(0.75))
                .overlay {
                    RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                        .strokeBorder(InsightColors.border, lineWidth: 1)
                }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    LocationContextChipView(caption: "Location attached (±12 m)", onClear: {})
        .padding()
        .background(InsightBackground())
        .preferredColorScheme(.dark)
}
