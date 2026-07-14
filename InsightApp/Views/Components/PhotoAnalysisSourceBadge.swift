import SwiftUI
import InsightCore

struct PhotoAnalysisSourceBadge: View {
    let source: VisionAnalysisSource

    var body: some View {
        OGMBadge.from(visionSource: source)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VStack(spacing: InsightSpacing.sm) {
        PhotoAnalysisSourceBadge(source: .ocrOnly)
        PhotoAnalysisSourceBadge(source: .ocrAndVlm)
    }
    .padding()
    .background(InsightBackground())
    .preferredColorScheme(.dark)
}
