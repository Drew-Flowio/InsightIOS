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
    private let knowledgeRetriever = KnowledgeRetriever()

    private let llm: any LlmServing
    private let stt: any SttServing
    private let tts: any TtsServing
    private let vision: (any VisionServing)?
    private let recorder: any AudioRecording
    private let onDeviceLLMEnabled: Bool
    private let llmBackendDebugDescription: String

    private var visualContext: VisualContext?
    private let cancelToken = CancellationToken()
    private var currentState: AppState = .idle
    private var turnCounter = 0

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
        self.llmBackendDebugDescription = services.llmBackendDebugDescription
        InsightEngineLog.info(services.llmBackendDebugDescription)

        try Self.seedInitialPromptIfNeeded(in: repository)
        MindBootstrap.seedBundledMindsIfNeeded(in: repository)
    }

    public var isMockMode: Bool {
        configuration.mockMode
    }

    public var usesOnDeviceLLM: Bool {
        onDeviceLLMEnabled
    }

    public func prepareRuntime() async throws {
        InsightEngineLog.info("Preparing LLM runtime; STT is deferred until voice capture to avoid concurrent heavy model residency.")
        try await llm.prepare()
        try await tts.prepare()
        InsightEngineLog.info("Runtime prepare complete.")
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
        InsightEngineLog.info("Voice flow: requesting microphone access and starting REAL recorder.")
        try await recorder.start()
        InsightEngineLog.info("Voice flow: microphone recorder started.")
        await setState(.listening, notify: onState)
    }

    public func cancelRecording(onState: (@Sendable (AppState) -> Void)? = nil) async throws {
        InsightEngineLog.info("Voice flow: cancelling microphone recording.")
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
            InsightEngineLog.info("Voice flow: recorder returned no audio URL.")
            await setState(.idle, notify: onState)
            return nil
        }
        InsightEngineLog.info("Voice flow: captured microphone audio at \(audioURL.lastPathComponent).")

        await setState(.transcribing, notify: onState)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        InsightEngineLog.info("Voice flow: sending captured audio to REAL Whisper transcription.")
        let transcript = try await stt.transcribe(audioURL: audioURL)
        InsightEngineLog.info("Voice flow: Whisper transcript: \(transcript)")
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
        let context = try await analyzeImage(at: storedURL, using: vision)
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

    public func getKnowledgeSourcesByMessageID() -> [String: [KnowledgeSourceAttribution]] {
        let rows = repository.listMessageKnowledgeSources(forSession: sessionManager.currentSession.id)
        var grouped: [String: [KnowledgeSourceAttribution]] = [:]
        for row in rows {
            let source = KnowledgeSourceAttribution(
                volumeID: row.volumeID,
                volumeTitle: row.volumeTitle,
                recordID: row.recordID,
                recordTitle: row.recordTitle,
                excerpt: row.excerpt
            )
            grouped[row.messageID, default: []].append(source)
        }
        return grouped
    }

    public func listInstalledMinds() -> [KnowledgeVolumeRecord] {
        repository.listKnowledgeVolumes()
    }

    public func listEnabledMinds() -> [KnowledgeVolumeRecord] {
        repository.listEnabledKnowledgeVolumes()
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
            sessionSummary: "\(count) message(s) in the current session.",
            runtimeDebugDescription: llmBackendDebugDescription
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
        turnCounter += 1
        let turnID = turnCounter
        let started = CFAbsoluteTimeGetCurrent()

        InsightEngineLog.info("Turn \(turnID) starting: source=\(source), recordUser=\(recordUser), existingMessages=\(sessionManager.messageCount()).")

        let activePrompt = repository.getActivePromptVersion()
        let personalityPrompt = activePrompt?.content ?? DefaultPrompts.bundledSystemPrompt()
        let relevantMemory = retrieveRelevantMemory(for: utterance)
        let retrievedKnowledge = retrieveRelevantKnowledge(for: utterance)
        let (historyMessages, summaryNote) = sessionManager.getPromptHistoryMessages()
        let recentConversation = promptBuilder.summarizeConversation(
            historyMessages: historyMessages,
            summaryNote: summaryNote
        )

        let (messages, debugText) = promptBuilder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: utterance,
                imageDescription: visualContext?.caption,
                relevantMemory: relevantMemory,
                retrievedKnowledge: retrievedKnowledge,
                recentConversation: recentConversation,
                timestamp: Date(),
                currentMode: source
            ),
            personalityPrompt: personalityPrompt
        )

        logAgentDebug(
            turnID: turnID,
            userQuestion: utterance,
            imageDescription: visualContext?.caption,
            relevantMemory: relevantMemory,
            retrievedKnowledge: retrievedKnowledge,
            promptLength: debugText.count
        )

        if recordUser {
            _ = sessionManager.recordUserMessage(text: utterance, source: source)
            InsightEngineLog.info("Turn \(turnID) user message persisted.")
        }

        await setState(.thinking, notify: onState)
        InsightEngineLog.info("Turn \(turnID) state set to thinking; unloading STT before LLM generation if loaded.")
        await stt.unload()

        let token = cancelToken
        let streamAccumulator = StreamAccumulator()
        let promptFormatter = promptBuilder
        var rawReplyText = ""

        do {
            rawReplyText = try await llm.generate(
                messages: messages,
                onToken: { piece in
                    guard !token.isCancelled else { return }
                    let cleaned = promptFormatter.sanitizeStreamingToken(piece)
                    guard !cleaned.isEmpty else { return }
                    streamAccumulator.append(cleaned)
                    onToken?(cleaned)
                },
                shouldCancel: { token.isCancelled }
            )
        } catch {
            if token.isCancelled {
                rawReplyText = streamAccumulator.text
            } else {
                throw error
            }
        }

        InsightEngineLog.info("Turn \(turnID) raw model response: \(rawReplyText)")
        InsightEngineLog.info("Turn \(turnID) LLM generation returned: chars=\(rawReplyText.count), cancelled=\(token.isCancelled).")

        let cancelled = token.isCancelled
        let validation = promptBuilder.validateAgentResponse(
            rawReplyText,
            imageDescription: visualContext?.caption,
            userQuestion: utterance
        )
        if let reason = validation.reason {
            InsightEngineLog.info("Turn \(turnID) response validation note: \(reason)")
        }
        let replyText = validation.text
        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)

        _ = sessionManager.recordAssistantMessage(
            text: replyText.isEmpty ? "(cancelled before any reply was generated)" : replyText,
            promptVersionID: activePrompt?.id,
            latencyMs: latencyMs,
            cancelled: cancelled,
            knowledgeSources: retrievedKnowledge.hits
        )
        InsightEngineLog.info("Turn \(turnID) assistant message persisted after \(latencyMs) ms.")

        let result = TurnResult(
            transcript: transcript,
            replyText: replyText,
            cancelled: cancelled,
            latencyMs: latencyMs,
            promptVersionID: activePrompt?.id,
            assembledPromptDebug: debugText,
            imageCaption: visualContext?.caption,
            knowledgeSources: retrievedKnowledge.hits
        )
        InsightEngineLog.info("Turn \(turnID) result built; returning to caller.")
        return result
    }

    private func analyzeImage(at imageURL: URL, using vision: any VisionServing) async throws -> VisualContext {
        let description = try await vision.describeImage(at: imageURL)
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let factualDescription = cleanedDescription.isEmpty
            ? "Unable to analyze this image. The image description is empty, so ask for another photo before making visual claims."
            : cleanedDescription

        InsightEngineLog.info("Image analysis completed for \(imageURL.lastPathComponent): \(factualDescription)")
        return VisualContext(imagePath: imageURL.path, caption: factualDescription)
    }

    private func retrieveRelevantMemory(for userQuestion: String) -> RelevantMemoryContext {
        let facts = repository.listMemoryFacts().map(\.text)
        guard !facts.isEmpty else { return RelevantMemoryContext() }

        let questionTokens = Self.keywords(in: userQuestion)
        let scoredFacts = facts.compactMap { fact -> (text: String, score: Int, category: MemoryCategory)? in
            let category = Self.category(forMemoryFact: fact)
            let factTokens = Self.keywords(in: fact)
            let overlap = questionTokens.intersection(factTokens).count
            let alwaysUsefulPreference = category == .preference && Self.isAnswerStylePreference(fact)
            let score = overlap + (alwaysUsefulPreference ? 2 : 0)
            guard score > 0 else { return nil }
            return (fact, score, category)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.text.count < rhs.text.count }
            return lhs.score > rhs.score
        }
        .prefix(8)

        var preferences: [String] = []
        var userFacts: [String] = []
        var pastContext: [String] = []

        for item in scoredFacts {
            switch item.category {
            case .preference:
                preferences.append(item.text)
            case .userFact:
                userFacts.append(item.text)
            case .pastContext:
                pastContext.append(item.text)
            }
        }

        return RelevantMemoryContext(
            userPreferences: Array(preferences.prefix(3)),
            userFacts: Array(userFacts.prefix(3)),
            pastConversationContext: Array(pastContext.prefix(2))
        )
    }

    private func retrieveRelevantKnowledge(for userQuestion: String) -> RetrievedKnowledgeContext {
        let volumes = MindBootstrap.enabledVolumes(from: repository)
        return knowledgeRetriever.retrieve(query: userQuestion, volumes: volumes)
    }

    private func logAgentDebug(
        turnID: Int,
        userQuestion: String,
        imageDescription: String?,
        relevantMemory: RelevantMemoryContext,
        retrievedKnowledge: RetrievedKnowledgeContext,
        promptLength: Int
    ) {
        let llmConfig = configuration.llmConfig
        InsightEngineLog.info("Turn \(turnID) user question: \(userQuestion)")
        InsightEngineLog.info("Turn \(turnID) image description: \(imageDescription ?? "No image provided.")")
        InsightEngineLog.info("Turn \(turnID) memory used: \(relevantMemory.promptBlock())")
        InsightEngineLog.info("Turn \(turnID) knowledge used: \(retrievedKnowledge.hits.map(\.recordTitle).joined(separator: ", "))")
        InsightEngineLog.info("Turn \(turnID) final prompt length: \(promptLength) chars.")
        InsightEngineLog.info(
            "Turn \(turnID) model settings: model=\(llmConfig.modelFileName), context=\(llmConfig.contextLength), maxTokens=\(llmConfig.maxTokens), temperature=\(llmConfig.temperature), topP=\(llmConfig.topP), topK=\(llmConfig.topK), repeatPenalty=\(llmConfig.repeatPenalty)."
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

    private enum MemoryCategory {
        case preference
        case userFact
        case pastContext
    }

    private static func category(forMemoryFact fact: String) -> MemoryCategory {
        let lower = fact.lowercased()
        let preferenceMarkers = [
            "prefers",
            "preference",
            "likes",
            "dislikes",
            "wants",
            "answer style",
            "concise",
            "brief",
            "detailed",
            "units",
            "metric",
            "imperial",
        ]
        if preferenceMarkers.contains(where: lower.contains) {
            return .preference
        }

        let userFactMarkers = [
            "user is",
            "user has",
            "user owns",
            "user works",
            "user lives",
            "my ",
            "i am",
            "i have",
            "i own",
        ]
        if userFactMarkers.contains(where: lower.contains) {
            return .userFact
        }

        return .pastContext
    }

    private static func isAnswerStylePreference(_ fact: String) -> Bool {
        let lower = fact.lowercased()
        return lower.contains("answer") ||
            lower.contains("concise") ||
            lower.contains("brief") ||
            lower.contains("detailed") ||
            lower.contains("metric") ||
            lower.contains("imperial") ||
            lower.contains("units")
    }

    private static func keywords(in text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "and", "any", "are", "can", "could",
            "did", "does", "for", "from", "had", "has", "have", "how", "into",
            "is", "it", "its", "just", "like", "me", "my", "of", "on", "or",
            "our", "that", "the", "their", "them", "this", "to", "was", "what",
            "when", "where", "which", "with", "would", "you", "your"
        ]

        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            text.lowercased()
                .components(separatedBy: separators)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
        )
    }
}

private enum InsightEngineLog {
    static func info(_ message: String) {
        NSLog("[InsightEngine] %@", message)
    }
}

private final class StreamAccumulator: @unchecked Sendable {
    private(set) var text = ""

    func append(_ piece: String) {
        text += piece
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
