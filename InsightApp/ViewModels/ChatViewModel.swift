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
    var showCamera = false
    var showPhotoPicker = false
    var showMindsLibrary = false
    var selectedPhotoItem: PhotosPickerItem?

    private(set) var minds: [MindLibraryItem] = []
    private(set) var mindsFeedbackMessage: String?

    let assistantName: String

    private var engine: InsightEngine?
    private var configuration: AppConfiguration?
    private var activeTask: Task<Void, Never>?
    private let isPreviewOnly: Bool

    var isEngineReady: Bool {
        bootstrapState == .ready || bootstrapState == .preview
    }

    var isBusy: Bool {
        InsightTheme.isActiveState(appState) || activeTask != nil
    }

    var canSend: Bool {
        !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy && isEngineReady
    }

    init(assistantName: String = "Insight", previewMessages: [ChatDisplayMessage]? = nil) {
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

        composerText = ""
        appendUserMessage(text)
        haptic(.light)

        activeTask = Task {
            await performTextTurn(engine: engine, text: text)
        }
    }

    func toggleVoice() {
        guard let engine else { return }

        if isRecording {
            haptic(.medium)
            activeTask = Task {
                await performVoiceTurn(engine: engine)
            }
            return
        }

        guard !isBusy else { return }

        activeTask = Task {
            do {
                try await engine.startRecording { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
                isRecording = true
                haptic(.soft)
            } catch {
                errorMessage = error.localizedDescription
            }
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

                appendPhotoMessage(caption: context.caption, imageURL: URL(fileURLWithPath: context.imagePath))
                await engine.recordPhotoMessage(caption: context.caption)

                let greetingID = UUID().uuidString
                messages.append(ChatDisplayMessage(id: greetingID, role: .assistant, content: "", isStreaming: true))
                streamingMessageID = greetingID

                _ = try await engine.greetAfterPhoto(
                    onToken: { [weak self] token in
                        Task { @MainActor in
                            self?.appendStreamingToken(id: greetingID, token: token)
                        }
                    },
                    onState: { [weak self] state in
                        Task { @MainActor in self?.appState = state }
                    }
                )

                finalizeStreamingMessage(id: greetingID)
                await reloadHistory(from: engine)
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
                try? await engine.cancelRecording()
                isRecording = false
            }
            if let streamingMessageID {
                finalizeStreamingMessage(id: streamingMessageID)
            }
            appState = .idle
        }
    }

    func clearError() {
        errorMessage = nil
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

    func importMind(from url: URL) {
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
                let outcome = await engine.importMind(from: data)
                mindsFeedbackMessage = message(for: outcome)
                await loadMinds()
            } catch {
                mindsFeedbackMessage = "Could not read this Mind file."
            }
        }
    }

    func clearMindsFeedback() {
        mindsFeedbackMessage = nil
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
                bootstrapState = .downloading(nil)
                _ = try await InsightModelSetup.downloadWhisper(for: config) { [weak self] progress in
                    Task { @MainActor in
                        self?.bootstrapState = .downloading(progress.fractionCompleted)
                    }
                }
                await initializeEngine(with: config)
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
            if let context = await engine.getVisualContext() {
                photoContextCaption = context.caption
            }
            bootstrapState = .ready
        } catch {
            bootstrapState = .failed(error.localizedDescription)
        }
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

    private func performVoiceTurn(engine: InsightEngine) async {
        isRecording = false
        let streamID = UUID().uuidString
        messages.append(ChatDisplayMessage(id: streamID, role: .assistant, content: "", isStreaming: true))
        streamingMessageID = streamID
        do {
            let result = try await engine.sendVoiceUtterance(
                onTranscript: { [weak self] transcript in
                    Task { @MainActor in self?.appendUserMessage(transcript) }
                },
                onToken: { [weak self] token in
                    Task { @MainActor in
                        self?.appendStreamingToken(id: streamID, token: token)
                    }
                },
                onState: { [weak self] state in
                    Task { @MainActor in self?.appState = state }
                }
            )

            if result != nil {
                finalizeStreamingMessage(id: streamID)
                await reloadHistory(from: engine)
                haptic(.success)
            } else {
                messages.removeAll { $0.id == streamID }
                streamingMessageID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.removeAll { $0.id == streamID }
            streamingMessageID = nil
            appState = .idle
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
        messages = records.compactMap { mapRecord($0, sourcesByMessage: sourcesByMessage) }
    }

    private func mapRecord(
        _ record: MessageRecord,
        sourcesByMessage: [String: [KnowledgeSourceAttribution]]
    ) -> ChatDisplayMessage? {
        switch record.role {
        case "user":
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
                timestamp: parseTimestamp(record.timestamp)
            )
        case "assistant":
            let sources = (sourcesByMessage[record.id] ?? []).map {
                KnowledgeSourceDisplay(
                    id: $0.id,
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
                knowledgeSources: sources
            )
        default:
            return nil
        }
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
