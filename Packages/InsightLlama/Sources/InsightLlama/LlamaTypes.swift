import Foundation
import InsightRuntime
#if canImport(Metal) && (os(iOS) || os(tvOS) || os(visionOS) || os(macOS))
import Metal
#endif

enum LlamaRuntimeLog {
    static func info(_ message: String) {
        NSLog("[InsightLlama] %@", message)
    }

    static func llamaCpp(_ message: String) {
        NSLog("[llama.cpp] %@", message)
    }
}

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

    var usesGPU: Bool {
        self != .none
    }
}

public struct LlamaBackendSelection: Sendable {
    public let runtimeConfig: LlmRuntimeConfig
    public let backendName: String
    public let fallbackReason: String?

    public var debugDescription: String {
        if let fallbackReason {
            return "LLM backend: \(backendName). \(fallbackReason)"
        }
        return "LLM backend: \(backendName)."
    }

    static func select(from runtime: LlmRuntimeConfig) -> LlamaBackendSelection {
        let requestedGPULayers = GPULayers(configValue: runtime.gpuLayers)
        guard requestedGPULayers.usesGPU else {
            return LlamaBackendSelection(
                runtimeConfig: runtime,
                backendName: "llama.cpp CPU",
                fallbackReason: "Metal GPU offload not requested."
            )
        }

        if let disableReason = LlamaDeviceProfile.currentForBackendSelection.metalDisableReason {
            // The fallback decision happens here. Once preflight rejects Metal, the session is built
            // with gpuLayers=0 so later model loads and context rebuilds stay on the CPU path.
            return LlamaBackendSelection(
                runtimeConfig: runtime.replacingGPULayers(with: 0),
                backendName: "llama.cpp CPU",
                fallbackReason: disableReason
            )
        }

        return LlamaBackendSelection(
            runtimeConfig: runtime,
            backendName: "llama.cpp Metal",
            fallbackReason: nil
        )
    }
}

extension LlmRuntimeConfig {
    func replacingGPULayers(with gpuLayers: Int) -> LlmRuntimeConfig {
        LlmRuntimeConfig(
            modelFileName: modelFileName,
            contextLength: contextLength,
            maxTokens: maxTokens,
            batchSize: batchSize,
            temperature: temperature,
            topP: topP,
            topK: topK,
            repeatPenalty: repeatPenalty,
            gpuLayers: gpuLayers
        )
    }
}

struct LlamaLoadConfig: Sendable {
    let contextLength: UInt32
    let batchSize: Int32
    let gpuLayers: GPULayers
    let threads: Int
    let useMemoryMapping: Bool
    let useMemoryLocking: Bool
    let fallbackReason: String?

    init(from runtime: LlmRuntimeConfig, forceCPU: Bool = false, fallbackReason: String? = nil) {
        let profile = LlamaDeviceProfile.current
        let requestedGPULayers = GPULayers(configValue: runtime.gpuLayers)
        let requestedContextLength = max(runtime.contextLength, 512)
        let requestedBatchSize = max(runtime.batchSize, 32)

        self.contextLength = UInt32(min(requestedContextLength, profile.maxContextLength))
        self.batchSize = Int32(min(requestedBatchSize, profile.maxBatchSize))
        self.threads = min(max(ProcessInfo.processInfo.activeProcessorCount - 2, 2), 6)
        self.useMemoryMapping = true
        self.useMemoryLocking = false
        self.fallbackReason = fallbackReason

        if forceCPU {
            self.gpuLayers = .none
        } else {
            self.gpuLayers = requestedGPULayers
        }
    }
}

private struct LlamaDeviceProfile: Sendable {
    let maxContextLength: Int
    let maxBatchSize: Int
    let metalDisableReason: String?

    static var current: LlamaDeviceProfile {
        make(includeMetalPreflight: false)
    }

    static var currentForBackendSelection: LlamaDeviceProfile {
        make(includeMetalPreflight: true)
    }

    private static func make(includeMetalPreflight: Bool) -> LlamaDeviceProfile {
        let memory = ProcessInfo.processInfo.physicalMemory
        let hasHighMemory = memory >= 7_500_000_000
        let memoryReason = hasHighMemory ? nil : "Metal GPU offload disabled: device memory is below the safe 8 GB class threshold."
        let simulatorReason = includeMetalPreflight ? LlamaMetalPreflight.simulatorDisableReason : nil
        let metalReason = includeMetalPreflight && simulatorReason == nil && memoryReason == nil ? LlamaMetalPreflight.disabledReason() : nil

        return LlamaDeviceProfile(
            maxContextLength: hasHighMemory ? 2048 : 1536,
            maxBatchSize: hasHighMemory ? 128 : 64,
            metalDisableReason: simulatorReason ?? memoryReason ?? metalReason
        )
    }
}

private enum LlamaMetalPreflight {
    static var simulatorDisableReason: String? {
#if targetEnvironment(simulator)
        "Simulator detected: forcing llama.cpp CPU backend."
#else
        nil
#endif
    }

    static func disabledReason() -> String? {
        cachedDisabledReason
    }

    private static let cachedDisabledReason: String? = {
#if canImport(Metal) && (os(iOS) || os(tvOS) || os(visionOS))
        guard MTLCreateSystemDefaultDevice() != nil else {
            return "Metal GPU unavailable."
        }

        return nil
#else
        return "Metal GPU offload disabled: Metal not available in this build."
#endif
    }()
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
    case failedToLoadModel(URL, String?)
    case failedToCreateContext(String?)
    case tokenizationFailed
    case decodingFailed(Int32)
    case kvCacheFull
    case cancelled
    case promptFormattingFailed

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let url):
            "Model file not found at \(url.lastPathComponent)."
        case .failedToLoadModel(let url, let reason):
            if let reason, !reason.isEmpty {
                "Could not load model at \(url.lastPathComponent): \(reason)"
            } else {
                "Could not load model at \(url.lastPathComponent)."
            }
        case .failedToCreateContext(let reason):
            if let reason, !reason.isEmpty {
                "Could not create inference context: \(reason)"
            } else {
                "Could not create inference context."
            }
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
