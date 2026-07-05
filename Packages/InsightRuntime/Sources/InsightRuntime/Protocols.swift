import Foundation
import InsightCore

// MARK: - LLM

public struct LlmRuntimeConfig: Sendable, Equatable {
    public let modelFileName: String
    public let contextLength: Int
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double
    public let topK: Int32
    public let repeatPenalty: Double
    /// Metal GPU layers for llama.cpp on iPhone. `-1` means offload all layers.
    public let gpuLayers: Int

    public init(
        modelFileName: String,
        contextLength: Int = 2048,
        maxTokens: Int = 320,
        temperature: Double = 0.62,
        topP: Double = 0.90,
        topK: Int32 = 50,
        repeatPenalty: Double = 1.08,
        gpuLayers: Int = -1
    ) {
        self.modelFileName = modelFileName
        self.contextLength = contextLength
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.repeatPenalty = repeatPenalty
        self.gpuLayers = gpuLayers
    }
}

public protocol LlmServing: Sendable {
    func prepare() async throws
    func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) async throws -> String
}

// MARK: - Speech-to-text

public struct SttRuntimeConfig: Sendable, Equatable {
    public let modelFileName: String
    public let language: String
    public let threads: Int

    public init(modelFileName: String, language: String = "en", threads: Int = 4) {
        self.modelFileName = modelFileName
        self.language = language
        self.threads = threads
    }
}

public protocol SttServing: Sendable {
    func prepare() async throws
    func transcribe(audioURL: URL) async throws -> String
}

// MARK: - Text-to-speech

public struct TtsRuntimeConfig: Sendable, Equatable {
    public let referenceVoiceFileName: String
    public let language: String
    public let pythonExecutable: String
    public let scriptFileName: String
    /// Target speaking rate for XTTS (1.0 = medium conversational pace).
    public let speed: Double

    public init(
        referenceVoiceFileName: String = "insight_reference_voice.wav",
        language: String = "en",
        pythonExecutable: String = "/usr/bin/python3",
        scriptFileName: String = "insight_xtts_speak.py",
        speed: Double = 1.0
    ) {
        self.referenceVoiceFileName = referenceVoiceFileName
        self.language = language
        self.pythonExecutable = pythonExecutable
        self.scriptFileName = scriptFileName
        self.speed = speed
    }
}

public protocol TtsServing: Sendable {
    func prepare() async throws
    func speak(_ text: String) async throws
    func stop() async
}

// MARK: - Vision

public struct VisionRuntimeConfig: Sendable, Equatable {
    public let modelFileName: String
    public let mmprojFileName: String
    public let maxPredictTokens: Int
    public let temperature: Double
    public let gpuLayers: Int

    public init(
        modelFileName: String,
        mmprojFileName: String,
        maxPredictTokens: Int = 128,
        temperature: Double = 0.1,
        gpuLayers: Int = -1
    ) {
        self.modelFileName = modelFileName
        self.mmprojFileName = mmprojFileName
        self.maxPredictTokens = maxPredictTokens
        self.temperature = temperature
        self.gpuLayers = gpuLayers
    }
}

public protocol VisionServing: Sendable {
    func describeImage(at imageURL: URL) async throws -> String
}

// MARK: - Audio capture

public protocol AudioRecording: Sendable {
    var isRecording: Bool { get async }
    func start() async throws
    func cancel() async
    func stop() async throws -> URL?
}

public struct AudioRuntimeConfig: Sendable, Equatable {
    public let sampleRate: Int
    public let maxRecordingSeconds: Int

    public init(sampleRate: Int = 16_000, maxRecordingSeconds: Int = 20) {
        self.sampleRate = sampleRate
        self.maxRecordingSeconds = maxRecordingSeconds
    }
}
