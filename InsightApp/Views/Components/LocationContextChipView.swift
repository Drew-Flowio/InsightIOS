import SwiftUI
import InsightCore

struct LocationContextChipView: View {
    let caption: String
    let onClear: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: InsightSpacing.sm) {
            OGMBadge(kind: .location, text: "Location")

            Text(caption)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            Button(action: onClear) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(InsightColors.textTertiary)
                    .frame(width: InsightSpacing.minTouchTarget, height: 28)
                    .background(Circle().fill(InsightColors.surfaceOverlay))
            }
            .buttonStyle(.plain)
        }
        .padding(InsightSpacing.sm)
        .ogmCardBackground()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    LocationContextChipView(caption: "Location attached (±12 m)", onClear: {})
        .padding()
        .background(InsightBackground())
        .preferredColorScheme(.dark)
}
