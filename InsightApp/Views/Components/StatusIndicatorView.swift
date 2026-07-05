import SwiftUI
import InsightCore

struct StatusIndicatorView: View {
    let state: AppState
    let assistantName: String

    @State private var pulse = false

    var body: some View {
        HStack(spacing: InsightSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(assistantName)
                    .font(InsightTypography.title())
                    .foregroundStyle(InsightColors.textPrimary)

                HStack(spacing: InsightSpacing.xs) {
                    Circle()
                        .fill(InsightTheme.statusColor(for: state))
                        .frame(width: 8, height: 8)
                        .shadow(color: InsightTheme.statusColor(for: state).opacity(0.8), radius: pulse ? 6 : 2)
                        .scaleEffect(InsightTheme.isActiveState(state) && pulse ? 1.15 : 1)

                    Text(InsightTheme.statusLabel(for: state))
                        .font(InsightTypography.micro())
                        .foregroundStyle(InsightColors.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
            }

            Spacer()
        }
        .padding(.horizontal, InsightSpacing.lg)
        .padding(.vertical, InsightSpacing.sm)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(InsightColors.border)
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

#Preview {
    ZStack {
        InsightBackground()
        VStack {
            StatusIndicatorView(state: .thinking, assistantName: "Insight")
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
