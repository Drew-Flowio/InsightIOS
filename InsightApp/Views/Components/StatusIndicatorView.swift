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
    var onOpenMap: (() -> Void)?
    var showsLocationIndicator: Bool = false

    @State private var pulse = false

    var body: some View {
        HStack(spacing: InsightSpacing.md) {
            if InsightTheme.isActiveState(state) {
                OGMBrandMark(style: .thinking, size: 28)
                    .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(assistantName)
                    .font(InsightTypography.title())
                    .foregroundStyle(InsightColors.textPrimary)
                    .tracking(0.4)

                HStack(spacing: InsightSpacing.xs) {
                    Circle()
                        .fill(InsightTheme.statusColor(for: state))
                        .frame(width: 7, height: 7)
                        .shadow(color: InsightTheme.statusColor(for: state).opacity(0.75), radius: pulse ? 5 : 2)
                        .scaleEffect(InsightTheme.isActiveState(state) && pulse ? 1.12 : 1)

                    Text(InsightTheme.statusLabel(for: state))
                        .ogmMicroLabel()
                        .foregroundStyle(InsightColors.textSecondary)
                }
                .animation(InsightTheme.stateTransition(state), value: state)

                if let personalityName, !personalityName.isEmpty {
                    Button(action: { onOpenPersonality?() }) {
                        Text(personalityName)
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(onOpenPersonality == nil)
                }
            }

            Spacer(minLength: 0)

            if showsLocationIndicator {
                OGMBadge(kind: .location, text: "GPS")
            }

            HStack(spacing: InsightSpacing.xxs) {
                if let onOpenMap {
                    Button(action: onOpenMap) {
                        Image(systemName: "map")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Map")
                }

                if let onOpenSetup {
                    Button(action: onOpenSetup) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Settings")
                }

                if let onOpenMinds {
                    Button(action: onOpenMinds) {
                        Image(systemName: "books.vertical")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Minds")
                }

                if let onOpenMemory {
                    Button(action: onOpenMemory) {
                        Image(systemName: "brain.head.profile")
                    }
                    .buttonStyle(InsightIconButtonStyle())
                    .accessibilityLabel("Memory")
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
        .animation(InsightTheme.stateTransition(state), value: state)
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
            StatusIndicatorView(state: .thinking, assistantName: "Offgrid Minds")
            Spacer()
        }
    }
    .preferredColorScheme(.dark)
}
