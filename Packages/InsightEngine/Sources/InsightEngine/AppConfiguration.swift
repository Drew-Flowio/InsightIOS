import Foundation
import InsightLlama
import InsightRuntime
import InsightVoice
import InsightWhisper

public struct AppConfiguration: Sendable {
    public let mockMode: Bool
    public let modelBundle: ModelCatalog.ModelBundle
    public let historyTurnsInPrompt: Int
    public let assistantName: String
    public let databaseURL: URL
    public let uploadsDirectoryURL: URL
    public let modelsDirectoryURL: URL

    public init(
        mockMode: Bool = false,
        modelBundle: ModelCatalog.ModelBundle = ModelCatalog.primary,
        historyTurnsInPrompt: Int = 8,
        assistantName: String = "Insight",
        databaseURL: URL,
        uploadsDirectoryURL: URL,
        modelsDirectoryURL: URL
    ) {
        self.mockMode = mockMode
        self.modelBundle = modelBundle
        self.historyTurnsInPrompt = historyTurnsInPrompt
        self.assistantName = assistantName
        self.databaseURL = databaseURL
        self.uploadsDirectoryURL = uploadsDirectoryURL
        self.modelsDirectoryURL = modelsDirectoryURL
    }

    public static func defaultForAppSupport(baseDirectory: URL) -> AppConfiguration {
        let support = baseDirectory.appendingPathComponent("InsightIOS", isDirectory: true)
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: ProcessInfo.processInfo.physicalMemory)
        return AppConfiguration(
            mockMode: false,
            modelBundle: bundle,
            databaseURL: support.appendingPathComponent("insight_app.db"),
            uploadsDirectoryURL: support.appendingPathComponent("uploads", isDirectory: true),
            modelsDirectoryURL: support.appendingPathComponent("models", isDirectory: true)
        )
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

        public var errorDescription: String? {
            switch self {
            case .llmModelMissing(let fileName):
                "Download the on-device model (\(fileName)) before chatting offline."
            }
        }
    }

    public struct Bundle: Sendable {
        public let llm: any LlmServing
        public let stt: any SttServing
        public let tts: any TtsServing
        public let vision: (any VisionServing)?
        public let recorder: any AudioRecording
        public let usesOnDeviceLLM: Bool
    }

    public static func make(for configuration: AppConfiguration) throws -> Bundle {
        if configuration.mockMode {
            return Bundle(
                llm: MockLlmAdapter(),
                stt: MockSttAdapter(),
                tts: MockTtsAdapter(),
                vision: MockVisionAdapter(),
                recorder: MockAudioRecorder(),
                usesOnDeviceLLM: false
            )
        }

        let store = configuration.modelStore
        guard store.isLLMReady else {
            throw Error.llmModelMissing(configuration.modelBundle.llmFileName)
        }

        let llm = LlamaCppLlmAdapter(
            modelPath: store.llmModelURL,
            runtimeConfig: configuration.llmConfig
        )

        let stt: any SttServing
        let recorder: any AudioRecording
        if store.isWhisperReady {
            stt = WhisperSttAdapter(modelPath: store.whisperModelURL)
            recorder = MicrophoneRecorder(config: configuration.audioConfig)
        } else {
            stt = MockSttAdapter()
            recorder = MockAudioRecorder()
        }

        let tts = VoiceRuntimeFactory.makeTts(
            config: configuration.ttsConfig,
            modelsDirectory: configuration.modelsDirectoryURL
        )

        return Bundle(
            llm: llm,
            stt: stt,
            tts: tts,
            vision: MockVisionAdapter(),
            recorder: recorder,
            usesOnDeviceLLM: true
        )
    }
}
