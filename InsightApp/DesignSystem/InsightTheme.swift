import SwiftUI
import InsightCore

enum InsightTheme {
    static let accentGradient = LinearGradient(
        colors: [InsightColors.accentBright, InsightColors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [
            InsightColors.backgroundGradientTop,
            InsightColors.background,
            InsightColors.backgroundGradientBottom,
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let userBubbleGradient = LinearGradient(
        colors: [InsightColors.userBubbleStart, InsightColors.userBubbleEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardMaterial = Material.ultraThinMaterial

    static func statusColor(for state: AppState) -> Color {
        switch state {
        case .idle: InsightColors.textTertiary
        case .listening: InsightColors.listening
        case .transcribing: InsightColors.thinking
        case .analyzing: InsightColors.glowBlueStrong
        case .thinking, .improvingPrompt: InsightColors.thinking
        case .streaming: InsightColors.accentBright
        case .speaking: InsightColors.success
        case .error: InsightColors.amber
        }
    }

    static func statusLabel(for state: AppState) -> String {
        switch state {
        case .idle: "Ready"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .analyzing: "Analyzing"
        case .thinking: "Thinking"
        case .improvingPrompt: "Improving"
        case .streaming: "Streaming"
        case .speaking: "Speaking"
        case .error: "Error"
        }
    }

    static func isActiveState(_ state: AppState) -> Bool {
        switch state {
        case .idle, .error: false
        default: true
        }
    }

    static func stateTransition(_ state: AppState) -> Animation {
        .spring(response: 0.38, dampingFraction: 0.86)
    }
}

struct InsightBackground: View {
    var body: some View {
        ZStack {
            InsightTheme.backgroundGradient
                .ignoresSafeArea()

            RadialGradient(
                colors: [InsightColors.glowBlue, .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [InsightColors.glowNavy, .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 340
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [InsightColors.amberSoft, .clear],
                center: UnitPoint(x: 0.5, y: 0.92),
                startRadius: 8,
                endRadius: 180
            )
            .ignoresSafeArea()
        }
    }
}

struct OGMCardBackground: ViewModifier {
    var cornerRadius: CGFloat = InsightSpacing.cardRadius

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(InsightColors.surfaceElevated.opacity(0.88))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(InsightColors.borderStrong, lineWidth: 1)
                    }
            }
    }
}

extension View {
    func ogmCardBackground(cornerRadius: CGFloat = InsightSpacing.cardRadius) -> some View {
        modifier(OGMCardBackground(cornerRadius: cornerRadius))
    }
}
