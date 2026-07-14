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
    private let memoryCommandParser = MemoryCommandParser()
    private let personalMemoryRetriever = PersonalMemoryRetriever()

    private let llm: any LlmServing
    private let stt: any SttServing
    private let tts: any TtsServing
    private let vision: (any VisionModelServing)?
    private let recorder: any AudioRecording
    private let runtimeCoordinator: ModelRuntimeCoordinator
    private let onDeviceLLMEnabled: Bool
    private let llmBackendDebugDescription: String

    private var visualContext: VisualContext?
    private var locationContext: LocationContext?
    private var runtimeNotice: String?
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
            at: configuration.manualsDirectoryURL,
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
        self.runtimeCoordinator = ModelRuntimeCoordinator(
            policy: configuration.residencyPolicy,
            llm: services.llm,
            stt: services.stt,
            vision: services.vision
        )
        self.onDeviceLLMEnabled = services.usesOnDeviceLLM
        self.llmBackendDebugDescription = services.llmBackendDebugDescription
        InsightEngineLog.info(services.llmBackendDebugDescription)

        try Self.seedInitialPromptIfNeeded(in: repository)
        Self.seedPersonalityIfNeeded(in: repository)
        MindBootstrap.seedBundledMindsIfNeeded(in: repository)
    }

    public var isMockMode: Bool {
        configuration.mockMode
    }

    public var usesOnDeviceLLM: Bool {
        onDeviceLLMEnabled
    }

    public func prepareRuntime() async throws {
        let tier = configuration.residencyPolicy.tierLabel
        InsightEngineLog.info("Preparing runtime for \(tier) memory tier; STT and vision load on demand.")
        if configuration.residencyPolicy.preloadsLLMAtBootstrap {
            try await runtimeCoordinator.acquireLLM()
        }
        try await tts.prepare()
        InsightEngineLog.info("Runtime prepare complete.")
    }

    public func consumeRuntimeNotice() -> String? {
        defer { runtimeNotice = nil }
        return runtimeNotice
    }

    // MARK: - Text

    @discardableResult
    public func sendTextMessage(
        _ text: String,
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult {
        let source = visualContext == nil ? "text" : "photo"
        let result = try await runTurn(
            utterance: text,
            source: source,
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

    public func transcribeRecording(onState: (@Sendable (AppState) -> Void)? = nil) async throws -> String? {
        guard let audioURL = try await recorder.stop() else {
            InsightEngineLog.info("Voice flow: recorder returned no audio URL.")
            await setState(.idle, notify: onState)
            return nil
        }
        InsightEngineLog.info("Voice flow: captured microphone audio at \(audioURL.lastPathComponent).")

        await setState(.transcribing, notify: onState)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        try await runtimeCoordinator.acquireSTT()

        InsightEngineLog.info("Voice flow: sending captured audio to REAL Whisper transcription.")
        let transcript: String
        do {
            transcript = try await stt.transcribe(audioURL: audioURL)
        } catch {
            await runtimeCoordinator.releaseSTT()
            throw error
        }

        if configuration.residencyPolicy.tier != .high {
            await runtimeCoordinator.releaseSTT()
        }
        InsightEngineLog.info("Voice flow: Whisper transcript: \(transcript)")

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await setState(.idle, notify: onState)
            return nil
        }

        await setState(.idle, notify: onState)
        return trimmed
    }

    @discardableResult
    public func sendVoiceMessage(
        _ text: String,
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult {
        let source = visualContext == nil ? "voice" : "photo"
        let result = try await runTurn(
            utterance: text,
            source: source,
            transcript: text,
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

    @discardableResult
    public func sendVoiceUtterance(
        onTranscript: (@Sendable (String) -> Void)? = nil,
        onToken: (@Sendable (String) -> Void)? = nil,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> TurnResult? {
        guard let transcript = try await transcribeRecording(onState: onState) else {
            return nil
        }

        onTranscript?(transcript)
        return try await sendVoiceMessage(
            transcript,
            onToken: onToken,
            onState: onState
        )
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

    public func setPhotoOcrText(_ text: String) {
        guard let context = visualContext else { return }
        visualContext = context.withEditedOcr(text)
    }

    public func getLocationContext() -> LocationContext? {
        locationContext
    }

    public func setLocationContext(_ context: LocationContext?) {
        locationContext = context
    }

    public func clearLocationContext() {
        locationContext = nil
    }

    public func attachPhoto(
        sourceURL: URL,
        onState: (@Sendable (AppState) -> Void)? = nil
    ) async throws -> VisualContext {
        guard vision != nil else {
            throw InsightEngineError.visionUnavailable
        }

        cancelToken.reset()
        await setState(.analyzing, notify: onState)

        let storedURL = try persistPhoto(from: sourceURL)
        var includeVisualReasoning = true
        var acquiredVision = false

        do {
            try await runtimeCoordinator.acquireVision()
            acquiredVision = true
        } catch let error as ModelRuntimeCoordinator.Error {
            includeVisualReasoning = false
            runtimeNotice = error.localizedDescription
        }

        let context = try await analyzeImage(
            at: storedURL,
            includeVisualReasoning: includeVisualReasoning
        )
        visualContext = context

        if acquiredVision {
            await runtimeCoordinator.releaseVision()
        }

        if let notice = await runtimeCoordinator.consumeNotice() {
            runtimeNotice = notice
        }

        await setState(.idle, notify: onState)
        return context
    }

    public func cancelCurrent() async {
        if await recorder.isRecording {
            await recorder.cancel()
        }
        cancelToken.cancel()
        await tts.stop()
        await runtimeCoordinator.evictAllHeavyModels()
    }

    // MARK: - Personality

    public func listPersonalityPresets() -> [PersonalityPreset] {
        PersonalityCatalog.presets
    }

    public func getActivePersonality() -> PersonalitySelection {
        resolveActivePersonality()
    }

    @discardableResult
    public func selectPersonality(presetID: String) -> PersonalitySelection {
        let settings = repository.getPersonalitySettings()
        let customPrompt = presetID == PersonalityCatalog.customPresetID
            ? settings?.customPrompt ?? PersonalityCatalog.defaultCustomSeed()
            : settings?.customPrompt
        _ = repository.savePersonalitySettings(activePresetID: presetID, customPrompt: customPrompt)
        return syncActivePersonalityPrompt()
    }

    @discardableResult
    public func updateCustomPersonalityPrompt(_ text: String) -> PersonalitySelection {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = repository.savePersonalitySettings(
            activePresetID: PersonalityCatalog.customPresetID,
            customPrompt: trimmed.isEmpty ? PersonalityCatalog.defaultCustomSeed() : trimmed
        )
        return syncActivePersonalityPrompt()
    }

    @discardableResult
    public func restoreDefaultPersonality() -> PersonalitySelection {
        _ = repository.savePersonalitySettings(
            activePresetID: PersonalityCatalog.defaultPresetID,
            customPrompt: repository.getPersonalitySettings()?.customPrompt
        )
        return syncActivePersonalityPrompt()
    }

    public func getSystemPrompt() -> String {
        resolveActivePersonality().promptText
    }

    @discardableResult
    public func updatePrompt(newText: String, label: String? = nil) -> PromptVersionRecord {
        _ = repository.savePersonalitySettings(
            activePresetID: PersonalityCatalog.customPresetID,
            customPrompt: newText
        )
        return repository.savePromptVersion(content: newText, label: label ?? PersonalityCatalog.customPresetID)
    }

    public func getPromptHistory() -> [PromptVersionRecord] {
        repository.listPromptVersions()
    }

    @discardableResult
    public func activatePromptVersion(versionID: String) -> PromptVersionRecord? {
        guard let version = repository.activatePromptVersion(versionID: versionID) else {
            return nil
        }
        _ = updateCustomPersonalityPrompt(version.content)
        return version
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

    public func getUserProfile() -> UserProfileContext {
        loadUserProfileContext()
    }

    @discardableResult
    public func updateUserProfile(
        displayName: String?,
        responseStyle: String?,
        generalNotes: String?
    ) -> UserProfileContext {
        _ = repository.upsertUserProfile(
            displayName: displayName,
            responseStyle: responseStyle,
            generalNotes: generalNotes
        )
        return loadUserProfileContext()
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

    public func listMindLibraryItems() -> [MindLibraryItem] {
        repository.listKnowledgeVolumes().map { volume in
            MindLibraryItem(
                id: volume.id,
                title: volume.title,
                version: volume.resolvedVersion,
                summary: volume.summary ?? "",
                isEnabled: volume.isEnabled,
                recordCount: repository.countKnowledgeRecords(volumeID: volume.id)
            )
        }
    }

    public func setMindEnabled(mindID: String, enabled: Bool) {
        repository.setKnowledgeVolumeEnabled(id: mindID, enabled: enabled)
    }

    public func importMind(from data: Data) -> MindImportOutcome {
        MindImporter.importOGPack(data: data, into: repository)
    }

    public func importManual(from data: Data, suggestedFilename: String) -> MindImportOutcome {
        ManualImporter.importPDF(
            data: data,
            suggestedFilename: suggestedFilename,
            into: repository,
            manualsDirectory: configuration.manualsDirectoryURL
        )
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

        if recordUser {
            let locationJSON = locationContext.flatMap { LocationSnapshotCodec.encode($0.snapshot) }
            if let context = visualContext, source == "photo" {
                let observationsJSON = context.analysis.visualObservations.flatMap {
                    VisualObservationsParser().encodeJSON($0)
                }
                _ = sessionManager.recordPhotoQuestion(
                    question: utterance,
                    imagePath: context.imagePath,
                    ocrText: context.analysis.resolvedOcrText(edited: context.editedOcrText),
                    visualObservationsJSON: observationsJSON,
                    locationJSON: locationJSON
                )
            } else {
                _ = sessionManager.recordUserMessage(
                    text: utterance,
                    source: source,
                    locationJSON: locationJSON
                )
            }
            InsightEngineLog.info("Turn \(turnID) user message persisted.")
        }

        if let memoryResult = handleMemoryCommandIfNeeded(
            utterance: utterance,
            activePrompt: activePrompt,
            started: started
        ) {
            InsightEngineLog.info("Turn \(turnID) handled as personal memory command.")
            return memoryResult
        }

        let personalityPrompt = resolveActivePersonality().promptText
        let userProfile = loadUserProfileContext()
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
                imageDescription: visualContext?.promptBlock(),
                locationDescription: locationContext?.promptBlock(),
                userProfile: userProfile,
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
            imageDescription: visualContext?.promptBlock(),
            userProfile: userProfile,
            relevantMemory: relevantMemory,
            retrievedKnowledge: retrievedKnowledge,
            promptLength: debugText.count
        )

        await setState(.thinking, notify: onState)
        InsightEngineLog.info("Turn \(turnID) acquiring LLM with runtime coordination.")
        try await runtimeCoordinator.acquireLLM()

        let token = cancelToken
        let streamAccumulator = StreamAccumulator()
        let promptFormatter = promptBuilder
        let streamingFlag = StreamingFlag()
        var rawReplyText = ""

        do {
            rawReplyText = try await llm.generate(
                messages: messages,
                onToken: { piece in
                    guard !token.isCancelled else { return }
                    let cleaned = promptFormatter.sanitizeStreamingToken(piece)
                    guard !cleaned.isEmpty else { return }
                    if !streamingFlag.value {
                        streamingFlag.value = true
                        Task { await self.markStreaming(notify: onState) }
                    }
                    streamAccumulator.append(cleaned)
                    onToken?(cleaned)
                },
                shouldCancel: { token.isCancelled }
            )
        } catch {
            await runtimeCoordinator.releaseLLMAfterTurnIfNeeded()
            if token.isCancelled {
                rawReplyText = streamAccumulator.text
            } else {
                throw error
            }
        }

        await runtimeCoordinator.releaseLLMAfterTurnIfNeeded()

        InsightEngineLog.info("Turn \(turnID) raw model response: \(rawReplyText)")
        InsightEngineLog.info("Turn \(turnID) LLM generation returned: chars=\(rawReplyText.count), cancelled=\(token.isCancelled).")

        let cancelled = token.isCancelled
        let validation = promptBuilder.validateAgentResponse(
            rawReplyText,
            imageDescription: visualContext?.promptBlock(),
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
            imageCaption: visualContext?.promptBlock(),
            locationCaption: locationContext?.responseFootnote,
            knowledgeSources: retrievedKnowledge.hits
        )
        locationContext = nil
        InsightEngineLog.info("Turn \(turnID) result built; returning to caller.")
        return result
    }

    private func analyzeImage(at imageURL: URL, includeVisualReasoning: Bool) async throws -> VisualContext {
        guard let vision else {
            throw InsightEngineError.visionUnavailable
        }

        var analysis = try await vision.analyzePhoto(
            at: imageURL,
            includeVisualReasoning: includeVisualReasoning
        )
        if analysis.imagePath != imageURL.path {
            analysis = PhotoAnalysisResult(
                imagePath: imageURL.path,
                width: analysis.width,
                height: analysis.height,
                ocrText: analysis.ocrText,
                detectedLabels: analysis.detectedLabels,
                faceCount: analysis.faceCount,
                barcodeCount: analysis.barcodeCount,
                visualObservations: analysis.visualObservations,
                visionAnalysisSource: analysis.visionAnalysisSource
            )
        }

        InsightEngineLog.info(
            "Photo analysis completed for \(imageURL.lastPathComponent): source=\(analysis.visionAnalysisSource.rawValue), ocr=\(analysis.ocrText.prefix(80))"
        )
        return VisualContext(analysis: analysis)
    }

    private func handleMemoryCommandIfNeeded(
        utterance: String,
        activePrompt: PromptVersionRecord?,
        started: CFAbsoluteTime
    ) -> TurnResult? {
        let command = memoryCommandParser.parse(utterance)
        guard command != .none else { return nil }

        let profile = loadUserProfileContext()
        let replyText: String

        switch command {
        case .remember(let fact):
            if personalMemoryRetriever.isValidMemoryFact(fact) {
                _ = repository.addMemoryFact(text: fact)
                replyText = "Got it — I'll remember that."
            } else {
                replyText = "I can only save short personal facts you explicitly ask me to remember."
            }

        case .recall(let query):
            let facts = repository.listMemoryFacts().map(\.text)
            replyText = personalMemoryRetriever.formatRecallReply(
                facts: facts,
                profile: profile,
                query: query
            )

        case .forget(let target):
            let normalized = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "everything" || normalized == "all" || normalized == "all my memories" {
                let count = repository.listMemoryFacts().count
                repository.clearAllMemoryFacts()
                replyText = count > 0
                    ? "Okay, I've cleared your saved personal memories."
                    : "You don't have any saved personal memories yet."
            } else {
                let activeFacts = repository.listMemoryFacts()
                let matchingTexts = Set(
                    personalMemoryRetriever.matchingFactTexts(
                        facts: activeFacts.map(\.text),
                        target: target
                    )
                )
                let idsToRemove = activeFacts.filter { matchingTexts.contains($0.text) }.map(\.id)
                idsToRemove.forEach { repository.removeMemoryFact(factID: $0) }
                switch idsToRemove.count {
                case 0:
                    replyText = "I couldn't find a matching memory to remove."
                case 1:
                    replyText = "Okay, I've forgotten that."
                default:
                    replyText = "Okay, I've removed \(idsToRemove.count) memories."
                }
            }

        case .none:
            return nil
        }

        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)
        _ = sessionManager.recordAssistantMessage(
            text: replyText,
            promptVersionID: activePrompt?.id,
            latencyMs: latencyMs,
            cancelled: false,
            knowledgeSources: []
        )

        return TurnResult(
            replyText: replyText,
            cancelled: false,
            latencyMs: latencyMs,
            promptVersionID: activePrompt?.id,
            assembledPromptDebug: "[MEMORY COMMAND]\n\(replyText)"
        )
    }

    private func loadUserProfileContext() -> UserProfileContext {
        guard let profile = repository.getUserProfile() else {
            return UserProfileContext()
        }
        return UserProfileContext(
            displayName: profile.displayName,
            responseStyle: profile.responseStyle,
            generalNotes: profile.generalNotes
        )
    }

    private func retrieveRelevantMemory(for userQuestion: String) -> RelevantMemoryContext {
        let facts = repository.listMemoryFacts().map(\.text)
        return personalMemoryRetriever.retrieve(facts: facts, for: userQuestion)
    }

    private func retrieveRelevantKnowledge(for userQuestion: String) -> RetrievedKnowledgeContext {
        let volumes = MindBootstrap.enabledVolumes(from: repository)
        var queryParts = [userQuestion]

        if let context = visualContext {
            queryParts.append(
                context.analysis.retrievalQuery(
                    userQuestion: userQuestion,
                    editedOcr: context.editedOcrText
                )
            )
        }

        if let location = locationContext {
            queryParts.append(location.retrievalQuery(userQuestion: userQuestion))
        }

        let query = queryParts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return knowledgeRetriever.retrieve(query: query, volumes: volumes)
    }

    private func logAgentDebug(
        turnID: Int,
        userQuestion: String,
        imageDescription: String?,
        userProfile: UserProfileContext,
        relevantMemory: RelevantMemoryContext,
        retrievedKnowledge: RetrievedKnowledgeContext,
        promptLength: Int
    ) {
        let llmConfig = configuration.llmConfig
        InsightEngineLog.info("Turn \(turnID) user question: \(userQuestion)")
        InsightEngineLog.info("Turn \(turnID) image description: \(imageDescription ?? "No image provided.")")
        InsightEngineLog.info("Turn \(turnID) location context: \(locationContext?.caption ?? "No location provided.")")
        InsightEngineLog.info("Turn \(turnID) profile used: \(userProfile.promptBlock())")
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

    private func markStreaming(notify handler: (@Sendable (AppState) -> Void)?) async {
        await setState(.streaming, notify: handler)
    }

    private static func seedInitialPromptIfNeeded(in repository: Repository) throws {
        if repository.getActivePromptVersion() != nil {
            return
        }
        _ = repository.savePromptVersion(
            content: DefaultPrompts.bundledSystemPrompt(),
            label: PersonalityCatalog.defaultPresetID
        )
    }

    private static func seedPersonalityIfNeeded(in repository: Repository) {
        guard repository.getPersonalitySettings() == nil else { return }
        _ = repository.savePersonalitySettings(
            activePresetID: PersonalityCatalog.defaultPresetID,
            customPrompt: PersonalityCatalog.defaultCustomSeed()
        )
    }

    @discardableResult
    private func syncActivePersonalityPrompt() -> PersonalitySelection {
        let selection = resolveActivePersonality()
        _ = repository.savePromptVersion(content: selection.promptText, label: selection.presetID)
        return selection
    }

    private func resolveActivePersonality() -> PersonalitySelection {
        let settings = repository.getPersonalitySettings()
        return PersonalityCatalog.resolveSelection(
            activePresetID: settings?.activePresetID ?? PersonalityCatalog.defaultPresetID,
            customPrompt: settings?.customPrompt
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

private enum InsightEngineLog {
    static func info(_ message: String) {
        NSLog("[InsightEngine] %@", message)
    }
}

private final class StreamingFlag: @unchecked Sendable {
    var value = false
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
