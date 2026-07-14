import Foundation
import InsightLlama
import InsightRuntime
import InsightVoice
import InsightWhisper

public struct AppConfiguration: Sendable {
    public let mockMode: Bool
    public let modelBundle: ModelCatalog.ModelBundle
    public let residencyPolicy: ModelResidencyPolicy
    public let historyTurnsInPrompt: Int
    public let assistantName: String
    public let databaseURL: URL
    public let uploadsDirectoryURL: URL
    public let manualsDirectoryURL: URL
    public let userImportsDirectoryURL: URL
    public let modelsDirectoryURL: URL

    public init(
        mockMode: Bool = false,
        modelBundle: ModelCatalog.ModelBundle = ModelCatalog.primary,
        residencyPolicy: ModelResidencyPolicy = ModelResidencyPolicy.current(),
        historyTurnsInPrompt: Int = 8,
        assistantName: String = "Insight",
        databaseURL: URL,
        uploadsDirectoryURL: URL,
        manualsDirectoryURL: URL,
        userImportsDirectoryURL: URL? = nil,
        modelsDirectoryURL: URL
    ) {
        self.mockMode = mockMode
        self.modelBundle = modelBundle
        self.residencyPolicy = residencyPolicy
        self.historyTurnsInPrompt = historyTurnsInPrompt
        self.assistantName = assistantName
        self.databaseURL = databaseURL
        self.uploadsDirectoryURL = uploadsDirectoryURL
        self.manualsDirectoryURL = manualsDirectoryURL
        self.userImportsDirectoryURL = userImportsDirectoryURL
            ?? uploadsDirectoryURL.appendingPathComponent("user-imports", isDirectory: true)
        self.modelsDirectoryURL = modelsDirectoryURL
    }

    public static func defaultForAppSupport(baseDirectory: URL) -> AppConfiguration {
        let support = baseDirectory.appendingPathComponent("InsightIOS", isDirectory: true)
        let modelsDirectory = support.appendingPathComponent("models", isDirectory: true)
        let bundle = resolvedModelBundle(
            forPhysicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            modelsDirectory: modelsDirectory
        )
        let mockMode = false
        return AppConfiguration(
            mockMode: mockMode,
            modelBundle: bundle,
            residencyPolicy: ModelResidencyPolicy.forPhysicalMemoryBytes(ProcessInfo.processInfo.physicalMemory),
            databaseURL: support.appendingPathComponent("insight_app.db"),
            uploadsDirectoryURL: support.appendingPathComponent("uploads", isDirectory: true),
            manualsDirectoryURL: support.appendingPathComponent("manuals", isDirectory: true),
            userImportsDirectoryURL: support.appendingPathComponent("user-imports", isDirectory: true),
            modelsDirectoryURL: modelsDirectory
        )
    }

    /// Uses the production bundle when installed; otherwise a ready internal fallback.
    static func resolvedModelBundle(
        forPhysicalMemoryBytes bytes: UInt64,
        modelsDirectory: URL
    ) -> ModelCatalog.ModelBundle {
        let recommended = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: bytes)
        let recommendedStore = ModelFileStore(modelsDirectory: modelsDirectory, bundle: recommended)
        if recommendedStore.isLLMReady {
            return recommended
        }

        let fallback = ModelCatalog.fallbackBundle(forPhysicalMemoryBytes: bytes)
        if fallback.llmFileName != recommended.llmFileName {
            let fallbackStore = ModelFileStore(modelsDirectory: modelsDirectory, bundle: fallback)
            if fallbackStore.isLLMReady {
                return fallback
            }
        }

        return recommended
    }

    public var modelStore: ModelFileStore {
        ModelFileStore(modelsDirectory: modelsDirectoryURL, bundle: modelBundle)
    }

    public var llmConfig: LlmRuntimeConfig { ModelCatalog.llmConfig(for: modelBundle) }
    public var sttConfig: SttRuntimeConfig { ModelCatalog.sttConfig(for: modelBundle) }
    public var ttsConfig: TtsRuntimeConfig { ModelCatalog.ttsConfig(for: modelBundle) }
    public var visionConfig: VisionRuntimeConfig { ModelCatalog.visionConfig(for: modelBundle) }
    public var audioConfig: AudioRuntimeConfig { AudioRuntimeConfig() }
}

public enum RuntimeServices: Sendable {
    public enum Error: Swift.Error, LocalizedError {
        case llmModelMissing(String)
        case whisperModelMissing(String)

        public var errorDescription: String? {
            switch self {
            case .llmModelMissing(let fileName):
                "Download the on-device model (\(fileName)) before chatting offline."
            case .whisperModelMissing(let fileName):
                "Download the speech recognition model (\(fileName)) before using the microphone."
            }
        }
    }

    public struct Bundle: Sendable {
        public let llm: any LlmServing
        public let stt: any SttServing
        public let tts: any TtsServing
        public let vision: (any VisionModelServing)?
        public let recorder: any AudioRecording
        public let usesOnDeviceLLM: Bool
        public let llmBackendDebugDescription: String
    }

    public static func make(for configuration: AppConfiguration) throws -> Bundle {
        if configuration.mockMode {
            RuntimeServicesLog.info("Startup service mode: MOCK. Explicit mockMode is enabled; using mock LLM, mock STT, mock vision, mock recorder, and mock TTS.")
            return Bundle(
                llm: MockLlmAdapter(),
                stt: MockSttAdapter(),
                tts: MockTtsAdapter(),
                vision: MockVisionAdapter(),
                recorder: MockAudioRecorder(),
                usesOnDeviceLLM: false,
                llmBackendDebugDescription: "LLM backend: mock."
            )
        }

        let store = configuration.modelStore
        guard store.isLLMReady else {
            throw Error.llmModelMissing(configuration.modelBundle.llmFileName)
        }
        guard store.isWhisperReady else {
            throw Error.whisperModelMissing(configuration.modelBundle.whisperFileName)
        }

        let llm = LlamaCppLlmAdapter(
            modelPath: store.llmModelURL,
            runtimeConfig: configuration.llmConfig
        )
        RuntimeServicesLog.info("Startup backend selection: \(llm.backendDebugDescription)")

        let stt: any SttServing = WhisperSttAdapter(modelPath: store.whisperModelURL)
        let recorder: any AudioRecording = MicrophoneRecorder(config: configuration.audioConfig)

        let tts = VoiceRuntimeFactory.makeTts(
            config: configuration.ttsConfig,
            modelsDirectory: configuration.modelsDirectoryURL
        )

        RuntimeServicesLog.info("Startup service mode: REAL. LLM=llama.cpp, STT=Whisper, Vision=OCR+SmolVLM(when installed), Recorder=AVAudioRecorder, TTS=system/XTTS.")

        let vision: any VisionModelServing = CompositeVisionAnalyzer(
            modelPath: store.visionModelURL,
            mmprojPath: store.visionMmprojURL,
            config: configuration.visionConfig
        )

        return Bundle(
            llm: llm,
            stt: stt,
            tts: tts,
            vision: vision,
            recorder: recorder,
            usesOnDeviceLLM: true,
            llmBackendDebugDescription: llm.backendDebugDescription
        )
    }
}

private enum RuntimeServicesLog {
    static func info(_ message: String) {
        NSLog("[RuntimeServices] %@", message)
    }
}
