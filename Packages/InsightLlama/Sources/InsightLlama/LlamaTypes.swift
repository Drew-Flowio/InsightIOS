import Foundation
import InsightRuntime

enum GPULayers: Sendable, Equatable {
    case all
    case none
    case count(Int32)

    init(configValue: Int) {
        switch configValue {
        case -1: self = .all
        case 0: self = .none
        default: self = .count(Int32(configValue))
        }
    }

    var rawValue: Int32 {
        switch self {
        case .all: 999
        case .none: 0
        case .count(let value): value
        }
    }
}

struct LlamaLoadConfig: Sendable {
    let contextLength: UInt32
    let batchSize: Int32
    let gpuLayers: GPULayers
    let threads: Int

    init(from runtime: LlmRuntimeConfig) {
        self.contextLength = UInt32(runtime.contextLength)
        self.batchSize = 512
        self.gpuLayers = GPULayers(configValue: runtime.gpuLayers)
        self.threads = min(max(ProcessInfo.processInfo.activeProcessorCount - 2, 2), 6)
    }
}

struct InferenceSampling: Sendable {
    let temperature: Float
    let topP: Float
    let topK: Int32
    let repeatPenalty: Float
    let maxTokens: Int32

    init(from runtime: LlmRuntimeConfig) {
        temperature = Float(runtime.temperature)
        topP = Float(runtime.topP)
        topK = runtime.topK
        repeatPenalty = Float(runtime.repeatPenalty)
        maxTokens = Int32(runtime.maxTokens)
    }
}

public enum LlamaRuntimeError: Error, LocalizedError, Sendable {
    case modelNotFound(URL)
    case failedToLoadModel(URL)
    case failedToCreateContext
    case tokenizationFailed
    case decodingFailed(Int32)
    case kvCacheFull
    case cancelled
    case promptFormattingFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let url):
            "Model file not found at \(url.lastPathComponent)."
        case .failedToLoadModel(let url):
            "Could not load model at \(url.lastPathComponent)."
        case .failedToCreateContext:
            "Could not create inference context."
        case .tokenizationFailed:
            "Could not tokenize the prompt."
        case .decodingFailed(let status):
            "Inference failed with status \(status)."
        case .kvCacheFull:
            "Conversation exceeded the context window."
        case .cancelled:
            "Generation was cancelled."
        case .promptFormattingFailed:
            "Could not format the chat prompt."
        }
    }
}
