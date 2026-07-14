import SwiftUI
import InsightCore

struct PhotoObservationsView: View {
    let observations: VisualObservations?
    let source: VisionAnalysisSource

    var body: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
            HStack {
                OGMBadge.from(visionSource: source)

                Spacer()

                if let observations {
                    Text("Confidence: \(observations.confidence.rawValue)")
                        .font(InsightTypography.micro())
                        .foregroundStyle(confidenceColor(for: observations.confidence))
                }
            }

            statusLine

            if let observations {
                if !observations.summary.isEmpty {
                    Text(observations.summary)
                        .font(InsightTypography.caption())
                        .foregroundStyle(InsightColors.textPrimary)
                }

                if !observations.visibleObjects.isEmpty {
                    observationLine(title: "Visible", values: observations.visibleObjects)
                }
                if !observations.readableLabels.isEmpty {
                    observationLine(title: "Labels", values: observations.readableLabels)
                }
                if !observations.possibleProblems.isEmpty {
                    observationLine(title: "Possible issues", values: observations.possibleProblems)
                }

                if observations.needsAnotherAngle {
                    Label("Another angle may help", systemImage: "camera.rotate")
                        .font(InsightTypography.caption())
                        .foregroundStyle(InsightColors.textSecondary)
                }
            }
        }
        .padding(InsightSpacing.sm)
        .background {
            RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                .fill(InsightColors.surfaceElevated.opacity(0.65))
                .overlay {
                    RoundedRectangle(cornerRadius: InsightSpacing.cardRadius, style: .continuous)
                        .strokeBorder(InsightColors.border, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch source {
        case .ocrAndVlm:
            Text("Visual reasoning is experimental — observations may be incomplete or wrong.")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
        case .vlmFailed:
            Text("Visual reasoning failed for this photo — showing OCR only.")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
        case .vlmUnavailable:
            Text("Enable Visual Reasoning in Setup to go beyond OCR.")
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
        case .ocrOnly:
            EmptyView()
        }
    }

    private func confidenceColor(for confidence: VisualConfidence) -> Color {
        switch confidence {
        case .high: InsightColors.accent
        case .medium: InsightColors.textSecondary
        case .low: InsightColors.textTertiary
        }
    }

    @ViewBuilder
    private func observationLine(title: String, values: [String]) -> some View {
        Text("\(title): \(values.joined(separator: ", "))")
            .font(InsightTypography.caption())
            .foregroundStyle(InsightColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    PhotoObservationsView(
        observations: VisualObservations(
            visibleObjects: ["gauge cluster"],
            readableLabels: ["120 PSI"],
            possibleProblems: ["needle near red zone"],
            confidence: .low,
            needsAnotherAngle: true,
            summary: "Pressure gauge with needle near the upper range."
        ),
        source: .ocrAndVlm
    )
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
