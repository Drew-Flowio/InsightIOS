import PhotosUI
import SwiftUI

struct MainChatView: View {
    @State private var viewModel: ChatViewModel

    init(previewMessages: [ChatDisplayMessage]? = nil) {
        _viewModel = State(initialValue: ChatViewModel(previewMessages: previewMessages))
    }

    var body: some View {
        ZStack {
            InsightBackground()

            VStack(spacing: 0) {
                StatusIndicatorView(
                    state: viewModel.appState,
                    assistantName: viewModel.assistantName,
                    personalityName: viewModel.activePersonalityName,
                    onOpenPersonality: { viewModel.showPersonalityScreen = true },
                    onOpenMinds: { viewModel.showMindsLibrary = true },
                    onOpenMemory: { viewModel.showMemoryScreen = true }
                )

                ChatTranscriptView(
                    messages: viewModel.messages,
                    assistantName: viewModel.assistantName,
                    appState: viewModel.appState,
                    streamingMessageID: viewModel.streamingMessageID
                )

                if viewModel.hasPhotoAttachment {
                    if viewModel.photoVisualObservations != nil || viewModel.photoVisionSource != .ocrOnly {
                        PhotoObservationsView(
                            observations: viewModel.photoVisualObservations,
                            source: viewModel.photoVisionSource
                        )
                        .padding(.horizontal, InsightSpacing.md)
                        .padding(.bottom, InsightSpacing.xs)
                    }

                    PhotoOcrEditView(
                        ocrText: $viewModel.photoOcrText,
                        thumbnailURL: viewModel.photoThumbnailURL,
                        onClear: viewModel.clearPhotoContext
                    )
                    .padding(.horizontal, InsightSpacing.md)
                    .padding(.bottom, InsightSpacing.xs)
                } else if let caption = viewModel.photoContextCaption {
                    PhotoContextChipView(
                        caption: caption,
                        thumbnailURL: viewModel.photoThumbnailURL
                    ) {
                        viewModel.clearPhotoContext()
                    }
                    .padding(.horizontal, InsightSpacing.md)
                    .padding(.bottom, InsightSpacing.xs)
                }

                ComposerBarView(
                    text: $viewModel.composerText,
                    placeholder: "Ask \(viewModel.assistantName) anything…",
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
            }

            if !viewModel.isEngineReady {
                ModelSetupOverlay(
                    bundle: viewModel.modelBundle,
                    state: viewModel.bootstrapState,
                    onDownload: viewModel.downloadModel,
                    onRetry: viewModel.retryBootstrap
                )
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $viewModel.selectedPhotoItem,
            matching: .images
        )
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            viewModel.handleSelectedPhoto()
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraPickerView(
                onImagePicked: { url in
                    viewModel.showCamera = false
                    viewModel.attachPhoto(from: url)
                },
                onCancel: {
                    viewModel.showCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.bootstrap()
        }
        .sheet(isPresented: $viewModel.showMindsLibrary) {
            MindsLibraryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showMemoryScreen) {
            MemoryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPersonalityScreen) {
            PersonalityView(viewModel: viewModel)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}

#Preview("Empty") {
    MainChatView()
}

#Preview("With messages") {
    MainChatView(previewMessages: ChatPreviewData.sampleMessages)
}
