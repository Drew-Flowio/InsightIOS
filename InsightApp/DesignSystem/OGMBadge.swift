import SwiftUI
import InsightCore

struct OGMBadge: View {
    enum Kind {
        case offline
        case mind
        case ocr
        case visualReasoning
        case location
        case sources
        case reducedFeature

        var icon: String {
            switch self {
            case .offline: "bolt.fill"
            case .mind: "books.vertical.fill"
            case .ocr: "text.viewfinder"
            case .visualReasoning: "sparkles"
            case .location: "location.fill"
            case .sources: "doc.text.magnifyingglass"
            case .reducedFeature: "minus.circle"
            }
        }

        var accent: Color {
            switch self {
            case .offline: InsightColors.accent
            case .mind: InsightColors.accentBright
            case .ocr: InsightColors.textSecondary
            case .visualReasoning: InsightColors.glowBlueStrong
            case .location: InsightColors.listening
            case .sources: InsightColors.accent
            case .reducedFeature: InsightColors.textTertiary
            }
        }
    }

    let kind: Kind
    let text: String
    var isActive: Bool = true

    var body: some View {
        HStack(spacing: InsightSpacing.xxs) {
            Image(systemName: kind.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .ogmMicroLabel()
        }
        .foregroundStyle(isActive ? kind.accent : InsightColors.textTertiary)
        .padding(.horizontal, InsightSpacing.sm)
        .padding(.vertical, InsightSpacing.xxs)
        .background {
            Capsule(style: .continuous)
                .fill(InsightColors.surfaceElevated.opacity(0.82))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            isActive ? kind.accent.opacity(0.28) : InsightColors.border,
                            lineWidth: 1
                        )
                }
        }
        .accessibilityLabel(text)
    }
}

extension OGMBadge {
    static func from(visionSource: VisionAnalysisSource) -> OGMBadge {
        switch visionSource {
        case .ocrAndVlm:
            OGMBadge(kind: .visualReasoning, text: visionSource.customerAnalysisLabel)
        case .ocrOnly, .vlmUnavailable, .vlmFailed:
            OGMBadge(kind: .ocr, text: visionSource.customerAnalysisLabel, isActive: visionSource == .ocrOnly)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        OGMBadge(kind: .offline, text: "Offline")
        OGMBadge(kind: .mind, text: "Mind")
        OGMBadge(kind: .ocr, text: "OCR only")
        OGMBadge(kind: .visualReasoning, text: "OCR + Visual Reasoning")
        OGMBadge(kind: .location, text: "Location")
        OGMBadge(kind: .sources, text: "Sources")
    }
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
