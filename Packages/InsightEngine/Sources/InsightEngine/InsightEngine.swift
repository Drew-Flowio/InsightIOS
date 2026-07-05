import Foundation
import InsightCore
import InsightRuntime
import InsightStorage

/// The one object the UI layer is allowed to talk to.
public actor InsightEngine {
    private let configuration: AppConfiguration
    private let repository: Repository
    private var sessionManager: SessionManager
    private let promptBuilder = PromptBuilder()

    private let llm: any LlmServing
    private let stt: any SttServing
    private let tts: any TtsServing
    private let vision: (any VisionServing)?
    private let recorder: any AudioRecording
    private let onDeviceLLMEnabled: Bool

    private var visualContext: VisualContext?
    private let cancelToken = CancellationToken()
    private var currentState: AppState = .idle

    public init(configuration: AppConfiguration) throws {
        self.configuration = configuration

        try FileManager.default.createDirectory(
            at: configuration.uploadsDirectoryURL,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: configuration.modelsDirectoryURL,
            withIntermediateDirectories: true
        )

        self.repository = try Repository(dbPath: configuration.databaseURL.path)
        self.sessionManager = SessionManager(
            repository: repository,
            historyTurnsInPrompt: configuration.historyTurnsInPrompt
        )

        let services = try RuntimeServices.make(for: configuration)
        self.llm = services.llm
        self.stt = services.stt
        self.tts = services.tts
        self.vision = services.vision
        self.recorder = services.recorder
        self.onDeviceLLMEnabled = services.usesOnDeviceLLM

        try Self.seedInitialPromptIfNeeded(in: repository)
    }

    public var isMockMode: Bool {
        configuration.mockMode
    }

    public var usesOnDeviceLLM: Bool {
        onDeviceLLMEnabled
    }

    public func prepareRuntime() async throws {
        try await llm.prepare()
        try await stt.prepare()
        try await tts.prepare()
    }

    // MARK: - Text

    @discardableResult
    public func sendTextMessage(
        _ text: String,
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult {
        let result = try await runTurn(
            utterance: text,
            source: "text",
            transcript: nil,
            recordUser: true,
            onToken: onToken,
            onState: onState
        )
        await setState(.idle, notify: onState)
        return result
    }

    @discardableResult
    public func greetAfterPhoto(
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult {
        let prompt = """
        The user just attached a photo. In 1-2 casual sentences, say what you see \
        and ask what they want to know about it.
        """
        let result = try await runTurn(
            utterance: prompt,
            source: "photo",
            transcript: nil,
            recordUser: false,
            onToken: onToken,
            onState: onState
        )
        await setState(.idle, notify: onState)
        return result
    }

    // MARK: - Voice

    public func startRecording(onState: (@Sendable (AppState) -> Void)? = nil) async throws {
        try await recorder.start()
        await setState(.listening, notify: onState)
    }

    public func cancelRecording(onState: (@Sendable (AppState) -> Void)? = nil) async throws {
        await recorder.cancel()
        await setState(.idle, notify: onState)
    }

    @discardableResult
    public func sendVoiceUtterance(
        onTranscript: (@Sendable (String) -> Void)? = nil,
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult? {
        guard let audioURL = try await recorder.stop() else {
            await setState(.idle, notify: onState)
            return nil
        }

        await setState(.transcribing, notify: onState)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let transcript = try await stt.transcribe(audioURL: audioURL)
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await setState(.idle, notify: onState)
            return nil
        }

        onTranscript?(transcript)

        let result = try await runTurn(
            utterance: transcript,
            source: "voice",
            transcript: transcript,
            recordUser: true,
            onToken: onToken,
            onState: onState
        )

        if !result.cancelled, !result.replyText.isEmpty, !cancelToken.isCancelled {
            await setState(.speaking, notify: onState)
            try await tts.speak(SpeechText.prepareForSpeech(result.replyText))
        }

        await setState(.idle, notify: onState)
        return result
    }

    public func speak(_ text: String, onState: (@Sendable (AppState) -> Void)? = nil) async throws {
        await setState(.speaking, notify: onState)
        try await tts.speak(SpeechText.prepareForSpeech(text))
        await setState(.idle, notify: onState)
    }

    // MARK: - Photos

    public func getVisualContext() -> VisualContext? {
        visualContext
    }

    public func clearVisualContext() {
        visualContext = nil
    }

    public func attachPhoto(
        sourceURL: URL,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> VisualContext {
        guard let vision else {
            throw InsightEngineError.visionUnavailable
        }

        cancelToken.reset()
        await setState(.analyzing, notify: onState)

        let storedURL = try persistPhoto(from: sourceURL)
        let caption = try await vision.describeImage(at: storedURL)
        let context = VisualContext(imagePath: storedURL.path, caption: caption)
        visualContext = context

        await setState(.idle, notify: onState)
        return context
    }

    public func recordPhotoMessage(caption: String) async {
        _ = sessionManager.recordUserMessage(
            text: "📷 Photo attached\n\(caption)",
            source: "photo"
        )
    }

    // MARK: - Cancellation

    public func cancelCurrent() async {
        if await recorder.isRecording {
            await recorder.cancel()
        }
        cancelToken.cancel()
        await tts.stop()
    }

    // MARK: - Personality

    public func getSystemPrompt() -> String {
        repository.getActivePromptVersion()?.content ?? ""
    }

    @discardableResult
    public func updatePrompt(newText: String, label: String? = nil) -> PromptVersionRecord {
        repository.savePromptVersion(content: newText, label: label)
    }

    public func getPromptHistory() -> [PromptVersionRecord] {
        repository.listPromptVersions()
    }

    @discardableResult
    public func activatePromptVersion(versionID: String) -> PromptVersionRecord? {
        repository.activatePromptVersion(versionID: versionID)
    }

    // MARK: - Memory

    public func listMemoryFacts() -> [MemoryFactRecord] {
        repository.listMemoryFacts()
    }

    @discardableResult
    public func addMemoryFact(text: String) -> MemoryFactRecord {
        repository.addMemoryFact(text: text)
    }

    public func removeMemoryFact(factID: String) {
        repository.removeMemoryFact(factID: factID)
    }

    // MARK: - Session

    public func getHistory() -> [MessageRecord] {
        sessionManager.getAllMessages()
    }

    public func resetMemory(scope: ResetScope = .session) async {
        sessionManager.reset(clearMemoryFacts: scope == .all)
        visualContext = nil
    }

    public func getSessionState() -> SessionStateView {
        let activePrompt = repository.getActivePromptVersion()
        let count = sessionManager.messageCount()
        return SessionStateView(
            sessionID: sessionManager.currentSession.id,
            messageCount: count,
            activePromptLabel: activePrompt?.label,
            activePromptVersionID: activePrompt?.id,
            memoryFactCount: repository.listMemoryFacts().count,
            currentState: currentState,
            sessionSummary: "\(count) message(s) in the current session."
        )
    }

    public var activeModelBundle: ModelCatalog.ModelBundle {
        configuration.modelBundle
    }

    // MARK: - Turn pipeline

    private func runTurn(
        utterance: String,
        source: String,
        transcript: String?,
        recordUser: Bool,
        onToken: (@Sendable (String) -> Void)?,
        onState: (@Sendable (AppState) -> Void)?
    ) async throws -> TurnResult {
        cancelToken.reset()
        let started = CFAbsoluteTimeGetCurrent()

        let activePrompt = repository.getActivePromptVersion()
        let personalityPrompt = activePrompt?.content ?? ""
        let memoryFacts = repository.listMemoryFacts().map(\.text)
        let (historyMessages, summaryNote) = sessionManager.getPromptHistoryMessages()

        let (messages, debugText) = promptBuilder.build(
            personalityPrompt: personalityPrompt,
            memoryFacts: memoryFacts,
            historyMessages: historyMessages,
            historySummaryNote: summaryNote,
            currentUtterance: utterance,
            visualContext: visualContext
        )

        if recordUser {
            _ = sessionManager.recordUserMessage(text: utterance, source: source)
        }

        await setState(.thinking, notify: onState)

        let token = cancelToken
        let replyText = try await llm.generate(
            messages: messages,
            onToken: onToken,
            shouldCancel: { token.isCancelled }
        )

        let cancelled = token.isCancelled
        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)

        _ = sessionManager.recordAssistantMessage(
            text: replyText.isEmpty ? "(cancelled before any reply was generated)" : replyText,
            promptVersionID: activePrompt?.id,
            latencyMs: latencyMs,
            cancelled: cancelled
        )

        return TurnResult(
            transcript: transcript,
            replyText: replyText,
            cancelled: cancelled,
            latencyMs: latencyMs,
            promptVersionID: activePrompt?.id,
            assembledPromptDebug: debugText,
            imageCaption: visualContext?.caption
        )
    }

    private func setState(_ state: AppState, notify handler: (@Sendable (AppState) -> Void)?) async {
        currentState = state
        handler?(state)
    }

    private static func seedInitialPromptIfNeeded(in repository: Repository) throws {
        if repository.getActivePromptVersion() != nil {
            return
        }
        _ = repository.savePromptVersion(
            content: DefaultPrompts.bundledSystemPrompt(),
            label: "initial"
        )
    }

    private func persistPhoto(from sourceURL: URL) throws -> URL {
        let uploads = configuration.uploadsDirectoryURL.standardizedFileURL
        let source = sourceURL.standardizedFileURL
        if source.deletingLastPathComponent() == uploads {
            return source
        }

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension.lowercased()
        let destination = uploads.appendingPathComponent("photo-\(UUID().uuidString.replacingOccurrences(of: "-", with: "")).\(ext)")
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }
}

public enum ResetScope: Sendable {
    case session
    case all
}

public enum InsightEngineError: Error, LocalizedError {
    case visionUnavailable

    public var errorDescription: String? {
        switch self {
        case .visionUnavailable:
            return "Photo analysis is not available. Download models or enable mock mode."
        }
    }
}
