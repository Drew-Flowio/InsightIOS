import PhotosUI
import SwiftUI
import InsightCore

struct MainChatView: View {
    @State private var viewModel: ChatViewModel

    init(viewModel: ChatViewModel? = nil, previewMessages: [ChatDisplayMessage]? = nil) {
        if let viewModel {
            _viewModel = State(initialValue: viewModel)
        } else {
            _viewModel = State(initialValue: ChatViewModel(previewMessages: previewMessages))
        }
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
                    onOpenMemory: { viewModel.showMemoryScreen = true },
                    onOpenSetup: { viewModel.showVisionSetupScreen = true },
                    onOpenMap: { viewModel.openMapWorkspace() },
                    showsLocationIndicator: viewModel.showsLocationIndicator
                )

                ChatTranscriptView(
                    messages: viewModel.messages,
                    assistantName: viewModel.assistantName,
                    appState: viewModel.appState,
                    streamingMessageID: viewModel.streamingMessageID,
                    onPhotoTap: { viewModel.openPhotoWorkspace(for: $0) },
                    onSourceTap: { source, message in
                        viewModel.openSourceWorkspace(source: source, from: message)
                    }
                )

                if viewModel.hasPhotoAttachment {
                    PhotoAnalysisSourceBadge(source: viewModel.photoVisionSource)
                        .padding(.horizontal, InsightSpacing.md)
                        .padding(.bottom, InsightSpacing.xxs)

                    if let notice = viewModel.photoRuntimeNotice {
                        Text(notice)
                            .font(InsightTypography.caption())
                            .foregroundStyle(InsightColors.textSecondary)
                            .padding(.horizontal, InsightSpacing.md)
                            .padding(.bottom, InsightSpacing.xxs)
                    }

                    if viewModel.photoVisualObservations != nil || viewModel.photoVisionSource == .ocrAndVlm {
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

                if let caption = viewModel.locationCaption {
                    LocationContextChipView(caption: caption) {
                        viewModel.clearLocationContext()
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

            if !viewModel.isEngineReady && ProductSetupStore.hasCompletedSetup {
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
            if ProductSetupStore.shouldShowDemoPrompt {
                viewModel.showDemoGuide = true
            }
        }
        .sheet(isPresented: $viewModel.showDemoGuide) {
            DemoGuideView(viewModel: viewModel)
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
        .sheet(isPresented: $viewModel.showVisionSetupScreen) {
            VisionSetupView(viewModel: viewModel)
        }
        .fullScreenCover(item: $viewModel.visualWorkspaceContext) { context in
            VisualWorkspaceView(viewModel: viewModel, context: context)
                .id(context.id)
        }
        .sheet(isPresented: $viewModel.showGeoMapScreen) {
            GeoMapView(viewModel: viewModel)
        }
        .confirmationDialog(
            "Include location for this question?",
            isPresented: $viewModel.showLocationConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Include Location") {
                viewModel.confirmLocationForPendingSend(includeLocation: true)
            }
            Button("Don't Include", role: .cancel) {
                viewModel.confirmLocationForPendingSend(includeLocation: false)
            }
        } message: {
            Text("Your coordinates stay on this device and help with local context. No place names are guessed from GPS alone.")
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
