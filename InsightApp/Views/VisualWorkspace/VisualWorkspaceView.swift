import SwiftUI
import InsightCore

struct VisualWorkspaceView: View {
    @Bindable var viewModel: ChatViewModel
    let context: VisualWorkspaceContext
    @Environment(\.dismiss) private var dismiss

    @State private var panelCollapsed = false
    @State private var pdfPageNumber: Int
    @State private var pdfPageCount: Int
    @State private var pdfURL: URL?

    init(viewModel: ChatViewModel, context: VisualWorkspaceContext) {
        self.viewModel = viewModel
        self.context = context
        if case .manualPage(_, _, let page, let count) = context.visual {
            _pdfPageNumber = State(initialValue: page)
            _pdfPageCount = State(initialValue: count)
        } else {
            _pdfPageNumber = State(initialValue: 1)
            _pdfPageCount = State(initialValue: 1)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                InsightBackground()

                if isLandscape(geometry) {
                    landscapeLayout(geometry)
                } else {
                    portraitLayout(geometry)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadPDFIfNeeded()
        }
    }

    private func isLandscape(_ geometry: GeometryProxy) -> Bool {
        geometry.size.width > geometry.size.height
    }

    @ViewBuilder
    private func portraitLayout(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            workspaceToolbar

            visualPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if panelCollapsed {
                collapsedComposerStrip
            } else {
                answerPanel
                    .padding(.horizontal, InsightSpacing.sm)
                    .padding(.bottom, InsightSpacing.xxs)

                workspaceComposer
            }
        }
    }

    @ViewBuilder
    private func landscapeLayout(_ geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            workspaceToolbar

            HStack(spacing: 0) {
                visualPane
                    .frame(width: geometry.size.width * 0.58)

                Divider()
                    .background(InsightColors.border)

                VStack(spacing: 0) {
                    answerPanel
                        .padding(InsightSpacing.sm)
                    workspaceComposer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var workspaceToolbar: some View {
        HStack {
            Button {
                viewModel.closeVisualWorkspace()
                dismiss()
            } label: {
                Label("Chat", systemImage: "chevron.down")
                    .font(InsightTypography.caption())
                    .foregroundStyle(InsightColors.textPrimary)
            }

            Spacer()

            Text(workspaceTitle)
                .font(InsightTypography.caption())
                .foregroundStyle(InsightColors.textSecondary)
                .lineLimit(1)

            Spacer()

            if case .manualPage = context.visual {
                pdfPageControls
            } else {
                Color.clear.frame(width: 44, height: 1)
            }
        }
        .padding(.horizontal, InsightSpacing.md)
        .padding(.vertical, InsightSpacing.sm)
        .background(InsightColors.surface.opacity(0.85))
    }

    @ViewBuilder
    private var visualPane: some View {
        switch context.visual {
        case .photo(let url):
            ZoomableImageView(imageURL: url)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(InsightSpacing.sm)

        case .map:
            WorkspaceMapContent(viewModel: viewModel)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(InsightSpacing.sm)

        case .manualPage(_, _, _, _):
            if let pdfURL {
                PDFPageViewer(pdfURL: pdfURL, pageIndex: pdfPageNumber - 1)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(InsightSpacing.sm)
            } else {
                ProgressView("Loading manual…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var answerPanel: some View {
        let content = viewModel.workspacePanelContent(for: context)
        return WorkspaceAnswerPanel(
            assistantName: viewModel.assistantName,
            answerText: content.answerText,
            isStreaming: content.isStreaming,
            photoObservations: content.photoObservations,
            photoOcrText: content.photoOcrText,
            sources: content.sources,
            isCollapsed: $panelCollapsed,
            onSourceTap: { source in
                viewModel.openSourceInWorkspace(source: source, anchorMessageID: context.anchorMessageID)
            }
        )
    }

    private var workspaceComposer: some View {
        ComposerBarView(
            text: $viewModel.composerText,
            placeholder: "Ask \(viewModel.assistantName)…",
            appState: viewModel.appState,
            isBusy: viewModel.isBusy,
            isRecording: viewModel.isRecording,
            canSend: viewModel.canSend,
            onSend: viewModel.sendMessage,
            onVoiceTap: viewModel.toggleVoice,
            onVoiceHoldStart: viewModel.beginHoldToTalk,
            onVoiceHoldEnd: viewModel.endHoldToTalk,
            onTakePhoto: { viewModel.showCamera = true },
            onSelectPhoto: { viewModel.showPhotoPicker = true },
            onStop: viewModel.cancelCurrent
        )
        .padding(.horizontal, InsightSpacing.sm)
        .padding(.bottom, InsightSpacing.xs)
        .background(InsightColors.surface.opacity(0.92))
    }

    private var collapsedComposerStrip: some View {
        VStack(spacing: InsightSpacing.xxs) {
            answerPanel
                .padding(.horizontal, InsightSpacing.sm)
            workspaceComposer
        }
    }

    private var workspaceTitle: String {
        switch context.visual {
        case .photo:
            return "Photo"
        case .map:
            return "Map"
        case .manualPage(_, let title, let page, _):
            return "\(title) · p. \(page)"
        }
    }

    private var pdfPageControls: some View {
        HStack(spacing: InsightSpacing.sm) {
            Button {
                goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(pdfPageNumber <= 1)

            Text("\(pdfPageNumber)/\(pdfPageCount)")
                .font(InsightTypography.micro())
                .monospacedDigit()

            Button {
                goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(pdfPageNumber >= pdfPageCount)
        }
        .foregroundStyle(InsightColors.textPrimary)
        .font(.system(size: 14, weight: .semibold))
    }

    private func goToPreviousPage() {
        guard pdfPageNumber > 1 else { return }
        pdfPageNumber -= 1
    }

    private func goToNextPage() {
        guard pdfPageNumber < pdfPageCount else { return }
        pdfPageNumber += 1
    }

    private func loadPDFIfNeeded() async {
        guard case .manualPage(let volumeID, _, _, _) = context.visual else { return }
        pdfURL = await viewModel.manualPDFURL(forVolumeID: volumeID)
        if pdfPageCount <= 1, let count = await viewModel.manualPDFPageCount(forVolumeID: volumeID) {
            pdfPageCount = count
        }
    }
}
