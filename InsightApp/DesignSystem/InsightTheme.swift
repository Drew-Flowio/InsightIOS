import SwiftUI
import InsightCore

enum InsightTheme {
    static let accentGradient = LinearGradient(
        colors: [InsightColors.accentBright, InsightColors.userBubbleEnd],
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

    static func statusColor(for state: AppState) -> Color {
        switch state {
        case .idle: InsightColors.textTertiary
        case .listening: InsightColors.listening
        case .transcribing: InsightColors.thinking
        case .analyzing: InsightColors.accent
        case .thinking: InsightColors.thinking
        case .speaking: InsightColors.success
        case .error: InsightColors.listening
        }
    }

    static func statusLabel(for state: AppState) -> String {
        switch state {
        case .idle: "Ready"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .analyzing: "Analyzing"
        case .thinking: "Thinking"
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
                endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [InsightColors.glowPurple, .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }
}
