import SwiftUI

struct KnowledgeSourcesSection: View {
    let sources: [KnowledgeSourceDisplay]
    @Binding var isExpanded: Bool
    var onSourceTap: ((KnowledgeSourceDisplay) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: InsightSpacing.xxs) {
                    OGMBadge(kind: .sources, text: "Sources (\(sources.count))")
                    Spacer(minLength: 0)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(InsightColors.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: InsightSpacing.sm) {
                    ForEach(sources) { source in
                        if source.isManualSource {
                            Button {
                                onSourceTap?(source)
                            } label: {
                                sourceRow(source)
                            }
                            .buttonStyle(.plain)
                        } else {
                            sourceRow(source)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, InsightSpacing.xxs)
    }

    private func sourceRow(_ source: KnowledgeSourceDisplay) -> some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
            HStack {
                Text("\(source.volumeTitle) · \(source.recordTitle)")
                    .font(InsightTypography.micro())
                    .foregroundStyle(InsightColors.accent)
                Spacer(minLength: 0)
                if source.isManualSource {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(InsightColors.textTertiary)
                }
            }

            Text(source.excerpt)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(InsightSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(InsightColors.surfaceElevated.opacity(0.65))
        }
    }
}
