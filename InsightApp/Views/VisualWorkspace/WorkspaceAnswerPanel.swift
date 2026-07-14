import SwiftUI
import InsightCore

struct WorkspaceAnswerPanel: View {
    let assistantName: String
    let answerText: String
    let isStreaming: Bool
    let photoObservations: String?
    let photoOcrText: String?
    let sources: [KnowledgeSourceDisplay]
    @Binding var isCollapsed: Bool
    let onSourceTap: (KnowledgeSourceDisplay) -> Void

    var body: some View {
        VStack(spacing: 0) {
            collapseHandle

            if !isCollapsed {
                ScrollView {
                    VStack(alignment: .leading, spacing: InsightSpacing.md) {
                        if !answerText.isEmpty || isStreaming {
                            answerSection
                        }

                        if let photoObservations, !photoObservations.isEmpty {
                            observationsSection(photoObservations)
                        } else if let photoOcrText, !photoOcrText.isEmpty {
                            observationsSection(photoOcrText)
                        }

                        if !sources.isEmpty {
                            sourcesSection
                        }
                    }
                    .padding(.horizontal, InsightSpacing.md)
                    .padding(.bottom, InsightSpacing.sm)
                }
                .frame(maxHeight: 280)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(InsightColors.surfaceElevated.opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(InsightColors.borderStrong, lineWidth: 1)
                }
        }
    }

    private var collapseHandle: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isCollapsed.toggle()
            }
        } label: {
            VStack(spacing: InsightSpacing.xxs) {
                Capsule()
                    .fill(InsightColors.textTertiary.opacity(0.5))
                    .frame(width: 36, height: 4)
                    .padding(.top, InsightSpacing.xs)

                HStack {
                    Text(isCollapsed ? "Show answer" : "Answer")
                        .font(InsightTypography.caption())
                        .foregroundStyle(InsightColors.textSecondary)
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(InsightColors.textTertiary)
                }
                .padding(.horizontal, InsightSpacing.md)
                .padding(.bottom, InsightSpacing.xs)
            }
        }
        .buttonStyle(.plain)
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
            Text(assistantName)
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.textTertiary)
                .textCase(.uppercase)

            HStack(alignment: .top, spacing: InsightSpacing.xs) {
                Text(answerText)
                    .font(InsightTypography.body())
                    .foregroundStyle(InsightColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if isStreaming {
                    StreamingIndicatorView()
                }
            }
        }
    }

    private func observationsSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
            Label("Photo observations", systemImage: "eye")
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.accent)

            Text(text)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(InsightSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(InsightColors.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: InsightSpacing.sm) {
            Label("Sources used (\(sources.count))", systemImage: "books.vertical.fill")
                .font(InsightTypography.micro())
                .foregroundStyle(InsightColors.textSecondary)

            ForEach(sources) { source in
                Button {
                    onSourceTap(source)
                } label: {
                    VStack(alignment: .leading, spacing: InsightSpacing.xxs) {
                        HStack {
                            Text("\(source.volumeTitle) · \(source.recordTitle)")
                                .font(InsightTypography.micro())
                                .foregroundStyle(InsightColors.accent)
                            Spacer()
                            if source.isManualSource {
                                Image(systemName: "doc.richtext")
                                    .font(.system(size: 11))
                                    .foregroundStyle(InsightColors.textTertiary)
                            }
                        }

                        Text(source.excerpt)
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(InsightSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(InsightColors.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!source.isManualSource)
            }
        }
    }
}
