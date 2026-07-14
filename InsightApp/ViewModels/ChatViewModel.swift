import Foundation
import Observation
import PhotosUI
import SwiftUI
import UIKit
import InsightCore
import InsightEngine
import InsightRuntime
import InsightStorage

enum AppBootstrapState: Equatable {
    case preview
    case needsModel
    case downloading(Double?)
    case loadingBrain
    case ready
    case failed(String)
}

enum VisionSetupState: Equatable {
    case checking
    case notInstalled
    case downloading(Double?)
    case ready
    case failed(String)
}

enum VoiceSetupState: Equatable {
    case notInstalled
    case downloading(Double?)
    case ready
    case failed(String)
}

struct UserDataImportDraft: Identifiable, Equatable {
    let id = UUID()
    let data: Data
    let filename: String
    let preview: UserDataImportPreview

    static func == (lhs: UserDataImportDraft, rhs: UserDataImportDraft) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatDisplayMessage] = []
    private(set) var appState: AppState = .idle
    private(set) var photoContextCaption: String?
    private(set) var bootstrapState: AppBootstrapState = .loadingBrain
    private(set) var isRecording = false
    private(set) var streamingMessageID: String?
    private(set) var errorMessage: String?
    private(set) var modelBundle: ModelCatalog.ModelBundle?

    var composerText = ""
    var photoOcrText = ""
    private(set) var photoThumbnailURL: URL?
    private(set) var photoVisualObservations: VisualObservations?
    private(set) var photoVisionSource: VisionAnalysisSource = .ocrOnly
    private(set) var photoRuntimeNotice: String?
    var showCamera = false
    var showPhotoPicker = false
    var showMindsLibrary = false
    var showMemoryScreen = false
    var showPersonalityScreen = false
    var showVisionSetupScreen = false
    var visualWorkspaceContext: VisualWorkspaceContext?
    var isPromptBuilderEnabled = false
    private(set) var promptBuilderOriginalText: String?
    var showStorageScreen = false
    var showDemoGuide = false
    var userDataImportDraft: UserDataImportDraft?
    var productSetupFinished = false
    var userDataImportTitle = ""
    var selectedPhotoItem: PhotosPickerItem?

    private(set) var visionSetupState: VisionSetupState = .checking
    private(set) var voiceSetupState: VoiceSetupState = .notInstalled
    private(set) var visionSetupErrorMessage: String?
    private(set) var libraryStorageSummary = LibraryStorageSummary(
        totalMinds: 0,
        manualCount: 0,
        importedDataCount: 0,
        bundledMindCount: 0
    )

    var locationPreference: LocationPreference = LocationPreferencesStore.load()
    private(set) var locationCaption: String?
    private(set) var locationAuthorizationState: LocationAuthorizationState = .notDetermined
    var showLocationConfirmDialog = false
    private var pendingSendAction: (() -> Void)?

    private let locationService = LocationService()

    private(set) var minds: [MindLibraryItem] = []
    private(set) var mindsFeedbackMessage: String?
    private(set) var memoryFacts: [MemoryFactRecord] = []
    private(set) var personalityPresets: [PersonalityPreset] = []
    private(set) var activePersonalityName = "Offgrid Guide"
    var selectedPersonalityID = PersonalityCatalog.defaultPresetID
    var customPersonalityPrompt = ""
    var userProfileName = ""
    var userProfileStyle = "balanced"
    var userProfileNotes = ""
    private var voiceSubmissionPending = false
    private var voiceCaptureUsesHold = false

    let assistantName: String

    private var engine: InsightEngine?
    private var configuration: AppConfiguration?
    private var activeTask: Task<Void, Never>?
    private let isPreviewOnly: Bool

    var isVoiceReady: Bool {
        configuration?.modelStore.isWhisperReady ?? false
    }

    var isOfflineBrainReady: Bool {
        configuration?.modelStore.isLLMReady ?? false
    }

    var isVisionReady: Bool {
        if case .ready = visionSetupState { return true }
        return configuration?.modelStore.isVisionReady ?? false
    }

    var isSetupDownloading: Bool {
        if case .downloading = bootstrapState { return true }
        return false
    }

    var isVoiceDownloading: Bool {
        if case .downloading = voiceSetupState { return true }
        return false
    }

    var isVisionDownloading: Bool {
        if case .downloading = visionSetupState { return true }
        return false
    }

    var offlineBrainSizeLabel: String {
        formatBytes(configuration.map { InsightModelSetup.offlineBrainDownloadBytes(for: $0) } ?? 0)
    }

    var voiceSizeLabel: String {
        formatBytes(configuration.map { InsightModelSetup.voiceDownloadBytes(for: $0) } ?? 0)
    }

    var visionSizeLabel: String {
        formatBytes(configuration.map { InsightModelSetup.visionDownloadBytes(for: $0) } ?? 0)
    }

    var productSetupSnapshot: ProductSetupSnapshot {
        ProductSetupStatusBuilder.snapshot(
            offlineBrainReady: isOfflineBrainReady,
            voiceReady: isVoiceReady,
            visionReady: isVisionReady,
            locationAuthorized: locationAuthorizationState == .authorized,
            demoMindInstalled: libraryStorageSummary.bundledMindCount > 0 || isEngineReady,
            skippedVoice: ProductSetupStore.skippedVoice,
            skippedVision: ProductSetupStore.skippedVision
        )
    }

    var isEngineReady: Bool {
        bootstrapState == .ready || bootstrapState == .preview
    }

    var isBusy: Bool {
        InsightTheme.isActiveState(appState) || activeTask != nil
    }

    var canSend: Bool {
        let hasQuestion = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasQuestion && !isBusy && isEngineReady
    }

    var canRestoreOriginalPrompt: Bool {
        promptBuilderOriginalText != nil
    }

    func restoreOriginalPrompt() {
        guard let original = promptBuilderOriginalText else { return }
        composerText = original
        promptBuilderOriginalText = nil
        haptic(.light)
    }

    var hasLocationContext: Bool {
        locationCaption != nil
    }

    var locationPermissionLabel: String {
        switch locationAuthorizationState {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .restricted: "Restricted"
        }
    }

    var showsLocationIndicator: Bool {
        locationPreference != .off && (hasLocationContext || locationAuthorizationState == .authorized)
    }

    var hasPhotoAttachment: Bool {
        photoThumbnailURL != nil
    }

    init(assistantName: String = ProductBranding.assistantName, previewMessages: [ChatDisplayMessage]? = nil) {
        self.assistantName = assistantName
        self.isPreviewOnly = previewMessages != nil
        if let previewMessages {
            self.messages = previewMessages
            self.bootstrapState = .preview
        }
    }

    func bootstrap() {
        guard engine == nil, !isPreviewOnly else { return }

        Task {
            await runBootstrap()
        }
    }

    func downloadOfflineBrainForSetup() {
        guard let configuration, !isOfflineBrainReady else { return }

        Task {
            bootstrapState = .downloading(nil)
            do {
                _ = try await InsightModelSetup.downloadLLM(for: configuration) { [weak self] progress in
                    Task { @MainActor in
                        self?.bootstrapState = .downloading(progress.fractionCompleted)
                    }
                }
                bootstrapState = .loadingBrain
            } catch {
                bootstrapState = .failed("Could not download the offline brain. Check your connection and free storage.")
            }
        }
    }

    func downloadVoiceForSetup() {
        guard let configuration, !isVoiceReady else { return }

        Task {
            voiceSetupState = .downloading(nil)
            do {
                _ = try await InsightModelSetup.downloadWhisper(for: configuration) { [weak self] progress in
                    Task { @MainActor in
                        self?.voiceSetupState = .downloading(progress.fractionCompleted)
                    }
                }
                voiceSetupState = .ready
                ProductSetupStore.skippedVoice = false
                if isEngineReady {
                    await reinitializeEngine(with: configuration)
                }
            } catch {
                voiceSetupState = .failed("Could not download voice support.")
            }
        }
    }

    func skipVoiceForSetup() {
        ProductSetupStore.skippedVoice = true
        voiceSetupState = .notInstalled
    }

    func skipVisionForSetup() {
        ProductSetupStore.skippedVision = true
        visionSetupState = .notInstalled
    }

    func completeProductSetup(openDemo: Bool) {
        Task {
            if let configuration, isOfflineBrainReady, !isEngineReady {
                await initializeEngine(with: configuration)
            }
            ProductSetupStore.markSetupCompleted(showDemoPrompt: openDemo)
            productSetupFinished = true
            if openDemo {
                showDemoGuide = true
            }
        }
    }

    func dismissDemoGuide() {
        showDemoGuide = false
        ProductSetupStore.shouldShowDemoPrompt = false
    }

    func startDemoWithText() {
        composerText = ProductBranding.demoSuggestedQuestion
        dismissDemoGuide()
    }

    func startDemoWithVoice() {
        dismissDemoGuide()
        guard isVoiceReady, let engine else {
            startDemoWithText()
            return
        }
        activeTask = Task {
            startVoiceRecording(engine: engine)
        }
    }

    func startDemoWithPhoto() {
        composerText = ProductBranding.demoSuggestedQuestion
        showPhotoPicker = true
        dismissDemoGuide()
    }

    func refreshStorageSummary() async {
        guard let engine else { return }
        libraryStorageSummary = await engine.libraryStorageSummary()
    }

    func removeVoiceModel() {
        guard let configuration else { return }

        Task {
            do {
                try InsightModelSetup.removeVoiceModel(for: configuration)
                voiceSetupState = .notInstalled
                ProductSetupStore.skippedVoice = true
            } catch {
                voiceSetupState = .failed("Could not remove voice support.")
            }
        }
    }

    func downloadModel() {
        guard case .needsModel = bootstrapState, let configuration else { return }

        Task {
            bootstrapState = .downloading(nil)
            do {
                _ = try await InsightModelSetup.downloadLLM(for: configuration) { [weak self] progress in
                    Task { @MainActor in
                        self?.bootstrapState = .downloading(progress.fractionCompleted.map { $0 * 0.85 })
                    }
                }
                _ = try await InsightModelSetup.downloadWhisper(for: configuration) { [weak self] progress in
                    Task { @MainActor in
                        if let fraction = progress.fractionCompleted {
                            self?.bootstrapState = .downloading(0.85 + fraction * 0.15)
                        }
                    }
                }
                await initializeEngine(with: configuration)
            } catch {
                bootstrapState = .failed(error.localizedDescription)
            }
        }
    }

    func retryBootstrap() {
        bootstrapState = .loadingBrain
        bootstrap()
    }

    func sendMessage() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let engine else { return }

        if isPromptBuilderEnabled {
            let captured = text
            let proceedImprove: () -> Void = { [weak self] in
                guard let self else { return }
                self.promptBuilderOriginalText = captured
                self.composerText = ""
                self.isPromptBuilderEnabled = false
                self.voiceSubmissionPending = false
                self.performPromptImprovement(engine: engine, roughQuestion: captured)
            }

            switch locationPreference {
            case .off:
                locationCaption = nil
                Task {
                    await engine.clearLocationContext()
                    proceedImprove()
                }
            case .on:
                activeTask = Task {
                    await self.attachLocationForTurn(engine: engine)
                    proceedImprove()
                }
            case .askEachTime:
                pendingSendAction = proceedImprove
                showLocationConfirmDialog = true
            }
            return
        }

        composerText = ""
        let useVoiceReply = voiceSubmissionPending
        voiceSubmissionPending = false

        let proceed: () -> Void = { [weak self] in
            guard let self else { return }
            if useVoiceReply {
                self.appendUserMessage(text)
                self.haptic(.light)
                self.activeTask = Task {
                    if self.hasPhotoAttachment {
                        await engine.setPhotoOcrText(self.photoOcrText)
                    }
                    await self.performVoiceReplyTurn(engine: engine, text: text)
                }
                return
            }

            if self.hasPhotoAttachment {
                self.appendUserMessage(text)
                self.haptic(.light)
                self.activeTask = Task {
                    await self.performPhotoQuestionTurn(engine: engine, text: text)
                }
                return
            }

            self.appendUserMessage(text)
            self.haptic(.light)
            self.activeTask = Task {
                await self.performTextTurn(engine: engine, text: text)
            }
        }

        switch locationPreference {
        case .off:
            locationCaption = nil
            Task { await engine.clearLocationContext() }
            proceed()
        case .on:
            activeTask = Task {
                await self.attachLocationForTurn(engine: engine)
                proceed()
            }
        case .askEachTime:
            pendingSendAction = proceed
            showLocationConfirmDialog = true
        }
    }

    func confirmLocationForPendingSend(includeLocation: Bool) {
        showLocationConfirmDialog = false
        guard let engine, let action = pendingSendAction else { return }
        pendingSendAction = nil

        activeTask = Task {
            if includeLocation {
                await self.attachLocationForTurn(engine: engine)
            } else {
                self.locationCaption = nil
                await engine.clearLocationContext()
            }
            action()
        }
    }

    func clearLocationContext() {
        locationCaption = nil
        guard let engine else { return }
        Task {
            await engine.clearLocationContext()
        }
    }

    func refreshLocationStatus() {
        locationService.refreshAuthorizationState()
        locationAuthorizationState = locationService.authorizationState
        locationPreference = LocationPreferencesStore.load()
    }

    func saveLocationPreference(_ preference: LocationPreference) {
        locationPreference = preference
        LocationPreferencesStore.save(preference)
        if preference == .off {
            clearLocationContext()
        }
    }

    func requestLocationPermission() {
        locationService.requestWhenInUseAuthorization()
        refreshLocationStatus()
    }

    func loadGeographicRecords() async -> [GeographicRecord] {
        guard let engine else { return [] }
        return await engine.listGeographicRecordsFromEnabledMinds()
    }

    func captureMapLocationSnapshot() async -> LocationSnapshot {
        await locationService.captureSnapshot()
    }

    // MARK: - Visual Workspace

    struct WorkspacePanelContent {
        let answerText: String
        let isStreaming: Bool
        let photoObservations: String?
        let photoOcrText: String?
        let sources: [KnowledgeSourceDisplay]
    }

    func openPhotoWorkspace(for message: ChatDisplayMessage) {
        guard message.role == .photo, let imageURL = message.imageURL else { return }
        visualWorkspaceContext = VisualWorkspaceContext(
            visual: .photo(imageURL),
            anchorMessageID: message.id,
            photoObservations: message.photoObservationsText
        )
        haptic(.light)
    }

    func openMapWorkspace() {
        visualWorkspaceContext = VisualWorkspaceContext(
            visual: .map,
            anchorMessageID: messages.last(where: { $0.isAssistant })?.id
        )
        haptic(.light)
    }

    func openSourceWorkspace(source: KnowledgeSourceDisplay, from message: ChatDisplayMessage) {
        guard source.isManualSource else { return }
        let page = source.manualPageNumber ?? 1
        Task {
            guard let engine else { return }
            let pageCount = await engine.manualPDFPageCount(forVolumeID: source.volumeID) ?? page
            visualWorkspaceContext = VisualWorkspaceContext(
                visual: .manualPage(
                    volumeID: source.volumeID,
                    volumeTitle: source.volumeTitle,
                    pageNumber: min(page, pageCount),
                    pageCount: pageCount
                ),
                anchorMessageID: message.id
            )
            haptic(.light)
        }
    }

    func openSourceInWorkspace(source: KnowledgeSourceDisplay, anchorMessageID: String?) {
        guard source.isManualSource else { return }
        let page = source.manualPageNumber ?? 1
        Task {
            guard let engine else { return }
            let pageCount = await engine.manualPDFPageCount(forVolumeID: source.volumeID) ?? page
            visualWorkspaceContext = VisualWorkspaceContext(
                visual: .manualPage(
                    volumeID: source.volumeID,
                    volumeTitle: source.volumeTitle,
                    pageNumber: min(page, pageCount),
                    pageCount: pageCount
                ),
                anchorMessageID: anchorMessageID
            )
            haptic(.light)
        }
    }

    func closeVisualWorkspace() {
        visualWorkspaceContext = nil
    }

    func workspacePanelContent(for context: VisualWorkspaceContext) -> WorkspacePanelContent {
        let assistant = relatedAssistantMessage(for: context)
        let photo = relatedPhotoMessage(for: context)
        let isStreaming = assistant?.id == streamingMessageID && (assistant?.isStreaming ?? false)
        return WorkspacePanelContent(
            answerText: assistant?.content ?? "",
            isStreaming: isStreaming,
            photoObservations: photo?.photoObservationsText ?? context.photoObservations,
            photoOcrText: photo?.photoOcrText,
            sources: assistant?.knowledgeSources ?? []
        )
    }

    func manualPDFURL(forVolumeID volumeID: String) async -> URL? {
        guard let engine else { return nil }
        return await engine.manualPDFURL(forVolumeID: volumeID)
    }

    func manualPDFPageCount(forVolumeID volumeID: String) async -> Int? {
        guard let engine else { return nil }
        return await engine.manualPDFPageCount(forVolumeID: volumeID)
    }

    private func relatedAssistantMessage(for context: VisualWorkspaceContext) -> ChatDisplayMessage? {
        guard let anchorID = context.anchorMessageID,
              let index = messages.firstIndex(where: { $0.id == anchorID }) else { return nil }
        let anchor = messages[index]
        if anchor.isAssistant { return anchor }
        return messages.dropFirst(index + 1).first(where: { $0.isAssistant })
    }

    private func relatedPhotoMessage(for context: VisualWorkspaceContext) -> ChatDisplayMessage? {
        guard let anchorID = context.anchorMessageID,
              let index = messages.firstIndex(where: { $0.id == anchorID }) else { return nil }
        let anchor = messages[index]
        if anchor.role == .photo { return anchor }
        return messages.prefix(index).reversed().first(where: { $0.role == .photo })
    }

    private func workspaceDescriptionForPromptBuilder() -> String? {
        guard let context = visualWorkspaceContext else { return nil }
        switch context.visual {
        case .photo:
            return "User is viewing an attached photo in the visual workspace."
        case .map:
            return "User is viewing the offline map in the visual workspace."
        case .manualPage(_, let title, let page, let pageCount):
            return "User is viewing manual \"\(title)\" page \(page) of \(pageCount) in the visual workspace."
        }
    }

    private func performPromptImprovement(engine: InsightEngine, roughQuestion: String) {
        activeTask = Task {
            do {
                if hasPhotoAttachment {
                    await engine.setPhotoOcrText(photoOcrText)
                }

                let improved = try await engine.improveQuestion(
                    roughQuestion,
                    workspaceDescription: workspaceDescriptionForPromptBuilder(),
                    onState: { [weak self] state in
                        Task { @MainActor in self?.appState = state }
                    }
                )

                _ = PromptBuilderSendRouter.applyDraft(
                    improved: improved,
                    original: roughQuestion,
                    builderEnabled: &isPromptBuilderEnabled
                )
                composerText = improved
                haptic(.soft)
            } catch {
                composerText = roughQuestion
                promptBuilderOriginalText = nil
                isPromptBuilderEnabled = false
                errorMessage = error.localizedDescription
                appState = .idle
            }
            activeTask = nil
        }
    }

    private func attachLocationForTurn(engine: InsightEngine) async {
        let snapshot = await locationService.captureSnapshot()
        guard snapshot.quality != .denied, snapshot.quality != .unavailable else {
            locationCaption = nil
            await engine.clearLocationContext()
            return
        }

        let context = LocationContext(snapshot: snapshot)
        locationCaption = context.caption
        await engine.setLocationContext(context)
    }

    func toggleVoice() {
        guard let engine else { return }

        if isRecording {
            voiceCaptureUsesHold = false
            haptic(.medium)
            activeTask = Task {
                await finishVoiceCapture(autoSubmit: false)
            }
            return
        }

        guard isVoiceReady else {
            errorMessage = "Voice support is not installed. Open Setup → Storage to download Whisper."
            return
        }

        guard !isBusy else { return }
        startVoiceRecording(engine: engine)
    }

    func beginHoldToTalk() {
        guard let engine, !isRecording, !isBusy else { return }
        guard isVoiceReady else {
            errorMessage = "Voice support is not installed. Open Setup → Storage to download Whisper."
            return
        }
        voiceCaptureUsesHold = true
        startVoiceRecording(engine: engine)
    }

    func endHoldToTalk() {
        guard isRecording, voiceCaptureUsesHold else { return }
        haptic(.medium)
        activeTask = Task {
            await finishVoiceCapture(autoSubmit: true)
        }
    }

    private func startVoiceRecording(engine: InsightEngine) {
        activeTask = Task {
            do {
                try await engine.startRecording { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
                isRecording = true
                haptic(.soft)
            } catch {
                handleVoiceError(error)
            }
            activeTask = nil
        }
    }

    private func finishVoiceCapture(autoSubmit: Bool) async {
        guard let engine else { return }
        isRecording = false
        voiceCaptureUsesHold = false

        do {
            guard let transcript = try await engine.transcribeRecording(onState: voiceStateHandler) else {
                return
            }

            composerText = transcript
            voiceSubmissionPending = true

            if autoSubmit {
                sendMessage()
            }
        } catch {
            handleVoiceError(error)
        }
        activeTask = nil
    }

    private func handleVoiceError(_ error: Error) {
        isRecording = false
        voiceCaptureUsesHold = false
        voiceSubmissionPending = false
        appState = .error
        errorMessage = error.localizedDescription
    }

    private var voiceStateHandler: @Sendable (AppState) -> Void {
        { [weak self] state in
            Task { @MainActor in self?.appState = state }
        }
    }

    func attachPhoto(from url: URL) {
        guard let engine else { return }

        activeTask = Task {
            do {
                let context = try await engine.attachPhoto(sourceURL: url) { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
                photoContextCaption = context.caption
                photoOcrText = context.analysis.ocrText
                photoVisualObservations = context.analysis.visualObservations
                photoVisionSource = context.analysis.visionAnalysisSource
                photoRuntimeNotice = await engine.consumeRuntimeNotice()
                photoThumbnailURL = URL(fileURLWithPath: context.imagePath)
                haptic(.success)
            } catch {
                errorMessage = error.localizedDescription
                appState = .idle
            }
            activeTask = nil
        }
    }

    func handleSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }
        selectedPhotoItem = nil

        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("insight-picked-\(UUID().uuidString).jpg")
            try? data.write(to: url)
            attachPhoto(from: url)
        }
    }

    func clearPhotoContext() {
        guard let engine else { return }
        Task {
            await engine.clearVisualContext()
            photoContextCaption = nil
            photoOcrText = ""
            photoVisualObservations = nil
            photoVisionSource = .ocrOnly
            photoRuntimeNotice = nil
            photoThumbnailURL = nil
        }
    }

    func cancelCurrent() {
        guard let engine else { return }
        haptic(.rigid)
        activeTask?.cancel()
        activeTask = nil

        Task {
            await engine.cancelCurrent()
            if isRecording {
                try? await engine.cancelRecording(onState: voiceStateHandler)
                isRecording = false
            }
            voiceSubmissionPending = false
            voiceCaptureUsesHold = false
            if let streamingMessageID {
                finalizeStreamingMessage(id: streamingMessageID)
            }
            appState = .idle
        }
    }

    func clearError() {
        errorMessage = nil
        if appState == .error {
            appState = .idle
        }
    }

    func loadMinds() async {
        guard let engine else { return }
        minds = await engine.listMindLibraryItems()
    }

    func setMindEnabled(id: String, enabled: Bool) {
        guard let engine else { return }

        Task {
            await engine.setMindEnabled(mindID: id, enabled: enabled)
            await loadMinds()
        }
    }

    func importLibraryFile(from url: URL) {
        guard let engine else { return }

        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let ext = url.pathExtension.lowercased()

                if ext == "pdf" {
                    let outcome = await engine.importManual(from: data, suggestedFilename: filename)
                    mindsFeedbackMessage = message(for: outcome)
                    await loadMinds()
                    return
                }

                if ext == "ogpack" || (ext == "json" && UserDataImporter.isOGPackJSON(data)) {
                    let outcome = await engine.importMind(from: data)
                    mindsFeedbackMessage = message(for: outcome)
                    await loadMinds()
                    return
                }

                if let preview = await engine.previewUserDataImport(data: data, filename: filename) {
                    userDataImportTitle = preview.suggestedTitle
                    userDataImportDraft = UserDataImportDraft(
                        data: data,
                        filename: filename,
                        preview: preview
                    )
                    return
                }

                mindsFeedbackMessage = "This file could not be imported. Try CSV, JSON, text, Markdown, PDF, or .ogpack."
            } catch {
                mindsFeedbackMessage = "Could not read the selected file."
            }
        }
    }

    func installUserDataImport() {
        guard let engine, let draft = userDataImportDraft else { return }

        Task {
            let outcome = await engine.importUserData(
                data: draft.data,
                filename: draft.filename,
                title: userDataImportTitle
            )
            cancelUserDataImport()
            mindsFeedbackMessage = message(for: outcome)
            await loadMinds()
        }
    }

    func cancelUserDataImport() {
        userDataImportDraft = nil
        userDataImportTitle = ""
    }

    func importMind(from url: URL) {
        importLibraryFile(from: url)
    }

    func clearMindsFeedback() {
        mindsFeedbackMessage = nil
    }

    func loadMemory() async {
        guard let engine else { return }
        memoryFacts = await engine.listMemoryFacts()
        let profile = await engine.getUserProfile()
        userProfileName = profile.displayName ?? ""
        userProfileStyle = profile.responseStyle ?? "balanced"
        userProfileNotes = profile.generalNotes ?? ""
    }

    func saveUserProfile() {
        guard let engine else { return }

        Task {
            _ = await engine.updateUserProfile(
                displayName: userProfileName,
                responseStyle: userProfileStyle,
                generalNotes: userProfileNotes
            )
        }
    }

    func deleteMemoryFact(id: String) {
        guard let engine else { return }

        Task {
            await engine.removeMemoryFact(factID: id)
            await loadMemory()
        }
    }

    func loadPersonality() async {
        guard let engine else { return }
        personalityPresets = await engine.listPersonalityPresets()
        let active = await engine.getActivePersonality()
        activePersonalityName = active.name
        selectedPersonalityID = active.presetID
        if active.presetID == PersonalityCatalog.customPresetID {
            customPersonalityPrompt = active.promptText
        }
    }

    func selectPersonality(id: String) {
        guard let engine else { return }

        Task {
            let selection = await engine.selectPersonality(presetID: id)
            activePersonalityName = selection.name
            selectedPersonalityID = selection.presetID
            if selection.presetID == PersonalityCatalog.customPresetID {
                customPersonalityPrompt = selection.promptText
            }
        }
    }

    func saveCustomPersonality() {
        guard let engine else { return }

        Task {
            let selection = await engine.updateCustomPersonalityPrompt(customPersonalityPrompt)
            activePersonalityName = selection.name
            selectedPersonalityID = selection.presetID
        }
    }

    func restoreDefaultPersonality() {
        guard let engine else { return }

        Task {
            let selection = await engine.restoreDefaultPersonality()
            activePersonalityName = selection.name
            selectedPersonalityID = selection.presetID
        }
    }

    func refreshVisionStatus() {
        guard let configuration else {
            visionSetupState = .notInstalled
            return
        }

        if case .downloading = visionSetupState {
            return
        }

        visionSetupState = InsightModelSetup.isVisionReady(for: configuration) ? .ready : .notInstalled
        voiceSetupState = configuration.modelStore.isWhisperReady ? .ready : .notInstalled
        visionSetupErrorMessage = nil
    }

    func downloadVision() {
        guard let configuration else { return }

        Task {
            visionSetupState = .downloading(nil)
            visionSetupErrorMessage = nil
            do {
                try await InsightModelSetup.downloadVision(for: configuration) { [weak self] progress in
                    Task { @MainActor in
                        self?.visionSetupState = .downloading(progress.fractionCompleted)
                    }
                }
                visionSetupState = .ready
                ProductSetupStore.skippedVision = false
            } catch {
                visionSetupState = .failed(error.localizedDescription)
                visionSetupErrorMessage = error.localizedDescription
            }
        }
    }

    func retryVisionDownload() {
        downloadVision()
    }

    func removeVisionModels() {
        guard let configuration else { return }

        Task {
            do {
                try InsightModelSetup.removeVisionModels(for: configuration)
                visionSetupState = .notInstalled
                visionSetupErrorMessage = nil
            } catch {
                visionSetupState = .failed(error.localizedDescription)
                visionSetupErrorMessage = error.localizedDescription
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func message(for outcome: MindImportOutcome) -> String {
        switch outcome {
        case .imported(let title):
            "Imported “\(title)”."
        case .duplicate(let title):
            "“\(title)” is already installed."
        case .failed(let message):
            message
        }
    }

    // MARK: - Private

    private func runBootstrap() async {
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let config = AppConfiguration.defaultForAppSupport(baseDirectory: support)
            configuration = config
            modelBundle = config.modelBundle

            if config.mockMode {
                await initializeEngine(with: config)
            } else if config.modelStore.isLLMReady, config.modelStore.isWhisperReady {
                await initializeEngine(with: config)
            } else if config.modelStore.isLLMReady {
                if ProductSetupStore.skippedVoice {
                    await initializeEngine(with: config)
                } else {
                    bootstrapState = .downloading(nil)
                    _ = try await InsightModelSetup.downloadWhisper(for: config) { [weak self] progress in
                        Task { @MainActor in
                            self?.bootstrapState = .downloading(progress.fractionCompleted)
                        }
                    }
                    await initializeEngine(with: config)
                }
            } else {
                bootstrapState = .needsModel
            }
        } catch {
            bootstrapState = .failed(error.localizedDescription)
        }
    }

    private func initializeEngine(with config: AppConfiguration) async {
        bootstrapState = .loadingBrain
        do {
            let engine = try InsightEngine(configuration: config)
            try await engine.prepareRuntime()
            self.engine = engine
            await reloadHistory(from: engine)
            await loadPersonality()
            if let context = await engine.getVisualContext() {
                photoContextCaption = context.caption
                photoOcrText = context.analysis.resolvedOcrText(edited: context.editedOcrText)
                photoVisualObservations = context.analysis.visualObservations
                photoVisionSource = context.analysis.visionAnalysisSource
                photoThumbnailURL = URL(fileURLWithPath: context.imagePath)
            }
            bootstrapState = .ready
            refreshVisionStatus()
            await refreshStorageSummary()
        } catch {
            bootstrapState = .failed(error.localizedDescription)
        }
    }

    private func reinitializeEngine(with config: AppConfiguration) async {
        engine = nil
        do {
            let engine = try InsightEngine(configuration: config)
            try await engine.prepareRuntime()
            self.engine = engine
            await reloadHistory(from: engine)
            refreshVisionStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performPhotoQuestionTurn(engine: InsightEngine, text: String) async {
        await engine.setPhotoOcrText(photoOcrText)

        let streamID = UUID().uuidString
        messages.append(ChatDisplayMessage(id: streamID, role: .assistant, content: "", isStreaming: true))
        streamingMessageID = streamID

        do {
            _ = try await engine.sendTextMessage(
                text,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.appendStreamingToken(id: streamID, token: token)
                    }
                },
                onState: { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
            )
            finalizeStreamingMessage(id: streamID)
            locationCaption = nil
            await reloadHistory(from: engine)
            haptic(.soft)
        } catch {
            errorMessage = error.localizedDescription
            messages.removeAll { $0.id == streamID }
            streamingMessageID = nil
            appState = .idle
        }
        activeTask = nil
    }

    private func performTextTurn(engine: InsightEngine, text: String) async {
        let streamID = UUID().uuidString
        messages.append(ChatDisplayMessage(id: streamID, role: .assistant, content: "", isStreaming: true))
        streamingMessageID = streamID

        do {
            _ = try await engine.sendTextMessage(
                text,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.appendStreamingToken(id: streamID, token: token)
                    }
                },
                onState: { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
            )
            finalizeStreamingMessage(id: streamID)
            locationCaption = nil
            await reloadHistory(from: engine)
            haptic(.soft)
        } catch {
            errorMessage = error.localizedDescription
            messages.removeAll { $0.id == streamID }
            streamingMessageID = nil
            appState = .idle
        }
        activeTask = nil
    }

    private func performVoiceReplyTurn(engine: InsightEngine, text: String) async {
        let streamID = UUID().uuidString
        messages.append(ChatDisplayMessage(id: streamID, role: .assistant, content: "", isStreaming: true))
        streamingMessageID = streamID

        do {
            _ = try await engine.sendVoiceMessage(
                text,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.appendStreamingToken(id: streamID, token: token)
                    }
                },
                onState: voiceStateHandler
            )
            finalizeStreamingMessage(id: streamID)
            locationCaption = nil
            await reloadHistory(from: engine)
            haptic(.success)
        } catch {
            handleVoiceError(error)
            messages.removeAll { $0.id == streamID }
            streamingMessageID = nil
        }
        activeTask = nil
    }

    private func appendUserMessage(_ text: String) {
        messages.append(ChatDisplayMessage(role: .user, content: text))
    }

    private func appendPhotoMessage(caption: String, imageURL: URL?) {
        messages.append(
            ChatDisplayMessage(
                role: .photo,
                content: caption,
                imageURL: imageURL
            )
        )
    }

    private func appendStreamingToken(id: String, token: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += token
        messages[index].isStreaming = true
    }

    private func updateStreamingMessage(id: String, content: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content = content
        messages[index].isStreaming = true
    }

    private func finalizeStreamingMessage(id: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else {
            streamingMessageID = nil
            return
        }
        messages[index].isStreaming = false
        streamingMessageID = nil
    }

    private func reloadHistory(from engine: InsightEngine) async {
        let records = await engine.getHistory()
        let sourcesByMessage = await engine.getKnowledgeSourcesByMessageID()
        var pendingLocationFootnote: String?

        messages = records.compactMap { record in
            if record.role == "user", let footnote = locationResponseFootnote(from: record.locationJSON) {
                pendingLocationFootnote = footnote
            }

            let message = mapRecord(
                record,
                sourcesByMessage: sourcesByMessage,
                assistantLocationLabel: record.role == "assistant" ? pendingLocationFootnote : nil
            )

            if record.role == "assistant" {
                pendingLocationFootnote = nil
            }

            return message
        }
    }

    private func mapRecord(
        _ record: MessageRecord,
        sourcesByMessage: [String: [KnowledgeSourceAttribution]],
        assistantLocationLabel: String? = nil
    ) -> ChatDisplayMessage? {
        let locationLabel = locationLabel(from: record.locationJSON)
        switch record.role {
        case "user":
            if record.source == "photo", let imagePath = record.imagePath {
                return ChatDisplayMessage(
                    id: record.id,
                    role: .photo,
                    content: record.content,
                    timestamp: parseTimestamp(record.timestamp),
                    imageURL: URL(fileURLWithPath: imagePath),
                    locationLabel: locationLabel,
                    photoObservationsText: photoObservationsSummary(from: record.visualObservationsJSON),
                    photoOcrText: record.ocrText
                )
            }
            if record.content.hasPrefix("📷 Photo attached") {
                let caption = record.content
                    .replacingOccurrences(of: "📷 Photo attached\n", with: "")
                return ChatDisplayMessage(
                    id: record.id,
                    role: .photo,
                    content: caption,
                    timestamp: parseTimestamp(record.timestamp)
                )
            }
            return ChatDisplayMessage(
                id: record.id,
                role: .user,
                content: record.content,
                timestamp: parseTimestamp(record.timestamp),
                locationLabel: locationLabel
            )
        case "assistant":
            let sources = (sourcesByMessage[record.id] ?? []).map {
                KnowledgeSourceDisplay(
                    id: $0.id,
                    volumeID: $0.volumeID,
                    recordID: $0.recordID,
                    volumeTitle: $0.volumeTitle,
                    recordTitle: $0.recordTitle,
                    excerpt: $0.excerpt
                )
            }
            return ChatDisplayMessage(
                id: record.id,
                role: .assistant,
                content: record.content,
                timestamp: parseTimestamp(record.timestamp),
                knowledgeSources: sources,
                locationLabel: assistantLocationLabel
            )
        default:
            return nil
        }
    }

    private func locationLabel(from json: String?) -> String? {
        guard let json, let snapshot = LocationSnapshotCodec.decode(json) else { return nil }
        let quality = snapshot.resolvedQuality()
        guard quality != .denied, quality != .unavailable else { return nil }
        return LocationContext(snapshot: snapshot).caption
    }

    private func locationResponseFootnote(from json: String?) -> String? {
        guard let json, let snapshot = LocationSnapshotCodec.decode(json) else { return nil }
        let quality = snapshot.resolvedQuality()
        guard quality != .denied, quality != .unavailable else { return nil }
        return LocationContext(snapshot: snapshot).responseFootnote
    }

    private func photoObservationsSummary(from json: String?) -> String? {
        guard let json, let observations = VisualObservationsParser().parse(json), !observations.isEmpty else {
            return nil
        }
        var parts: [String] = []
        if !observations.summary.isEmpty {
            parts.append(observations.summary)
        }
        if !observations.visibleObjects.isEmpty {
            parts.append("Visible: \(observations.visibleObjects.joined(separator: ", "))")
        }
        if !observations.readableLabels.isEmpty {
            parts.append("Labels: \(observations.readableLabels.joined(separator: ", "))")
        }
        if !observations.possibleProblems.isEmpty {
            parts.append("Possible issues: \(observations.possibleProblems.joined(separator: ", "))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    private func parseTimestamp(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value) ?? Date()
    }

    private func haptic(_ style: HapticStyle) {
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private enum HapticStyle {
        case light, medium, soft, rigid, success
    }
}
