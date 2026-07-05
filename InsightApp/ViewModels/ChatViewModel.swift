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
    var selectedPhotoItem: PhotosPickerItem?

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

                var streamed = ""
                _ = try await engine.greetAfterPhoto(
                    onToken: { [weak self] token in
                        Task { @MainActor in
                            streamed += token
                            self?.updateStreamingMessage(id: greetingID, content: streamed)
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

    // MARK: - Private

    private func runBootstrap() async {
        do {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let config = AppConfiguration.defaultForAppSupport(baseDirectory: support)
            configuration = config
            modelBundle = config.modelBundle

            if config.modelStore.isLLMReady, config.modelStore.isWhisperReady {
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

        var streamed = ""
        do {
            _ = try await engine.sendTextMessage(
                text,
                onToken: { [weak self] token in
                    Task { @MainActor in
                        streamed += token
                        self?.updateStreamingMessage(id: streamID, content: streamed)
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
        var streamed = ""

        do {
            let result = try await engine.sendVoiceUtterance(
                onTranscript: { [weak self] transcript in
                    Task { @MainActor in self?.appendUserMessage(transcript) }
                },
                onToken: { [weak self] token in
                    Task { @MainActor in
                        streamed += token
                        self?.updateStreamingMessage(id: streamID, content: streamed)
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
        messages = records.compactMap(mapRecord)
    }

    private func mapRecord(_ record: MessageRecord) -> ChatDisplayMessage? {
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
            return ChatDisplayMessage(
                id: record.id,
                role: .assistant,
                content: record.content,
                timestamp: parseTimestamp(record.timestamp)
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
