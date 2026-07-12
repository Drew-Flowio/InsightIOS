import SwiftUI
import InsightCore

struct StatusIndicatorView: View {
    let state: AppState
    let assistantName: String
    var personalityName: String?
    var onOpenPersonality: (() -> Void)?
    var onOpenMinds: (() -> Void)?
    var onOpenMemory: (() -> Void)?
    var onOpenSetup: (() -> Void)?

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

                if let personalityName, !personalityName.isEmpty {
                    Button(action: { onOpenPersonality?() }) {
                        Text(personalityName)
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .disabled(onOpenPersonality == nil)
                }
            }

            Spacer()

            HStack(spacing: InsightSpacing.xs) {
                if let onOpenSetup {
                    Button(action: onOpenSetup) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Setup")
                }

                if let onOpenPersonality {
                    Button(action: onOpenPersonality) {
                        Image(systemName: "theatermasks")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Personality")
                }

                if let onOpenMemory {
                    Button(action: onOpenMemory) {
                        Image(systemName: "brain.head.profile")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Memory")
                }

                if let onOpenMinds {
                    Button(action: onOpenMinds) {
                        Image(systemName: "books.vertical")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Minds")
                }
            }
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
