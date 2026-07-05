import Foundation
import InsightCore
import InsightRuntime

/// Loads Phi-3.5 once and runs streaming chat inference on Metal via llama.cpp.
public actor LlamaSession {
    private let modelPath: URL
    private let runtimeConfig: LlmRuntimeConfig
    private var modelHandle: LlamaModelHandle?
    private var contextHandle: LlamaContextHandle?
    private var sampler: LlamaSamplerChain?

    public init(modelPath: URL, runtimeConfig: LlmRuntimeConfig) {
        self.modelPath = modelPath
        self.runtimeConfig = runtimeConfig
    }

    public func prepare() throws {
        if modelHandle != nil { return }

        let loadConfig = LlamaLoadConfig(from: runtimeConfig)
        let model = try LlamaModelHandle(path: modelPath, loadConfig: loadConfig)
        let context = try LlamaContextHandle(modelHandle: model)
        let sampler = LlamaSamplerChain(sampling: InferenceSampling(from: runtimeConfig))

        self.modelHandle = model
        self.contextHandle = context
        self.sampler = sampler
    }

    public func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) throws -> String {
        try prepare()

        guard let modelHandle, let contextHandle, let sampler else {
            throw LlamaRuntimeError.failedToCreateContext
        }

        sampler.reset()

        let prompt = try ChatPromptFormatter.formatPrompt(messages: messages, model: modelHandle.model)
        let promptTokens = try contextHandle.tokenize(prompt)

        contextHandle.clearBatch()
        for (index, token) in promptTokens.enumerated() {
            contextHandle.addTokenToBatch(
                token,
                position: Int32(index),
                logits: index == promptTokens.count - 1
            )
        }
        try contextHandle.decode()

        var generated = ""
        var position = Int32(promptTokens.count)
        var pendingUTF8: [CChar] = []

        for _ in 0..<runtimeConfig.maxTokens {
            if shouldCancel?() == true {
                throw LlamaRuntimeError.cancelled
            }

            let token = sampler.sample(context: contextHandle.context)
            if contextHandle.isEndOfGeneration(token) {
                break
            }

            pendingUTF8.append(contentsOf: contextHandle.tokenToString(token))
            pendingUTF8.append(0)

            if let piece = String(validatingUTF8: pendingUTF8) {
                pendingUTF8.removeAll()
                if !piece.isEmpty {
                    generated += piece
                    onToken?(piece)
                }
            } else {
                pendingUTF8.removeLast()
            }

            contextHandle.clearBatch()
            contextHandle.addTokenToBatch(token, position: position, logits: true)
            try contextHandle.decode()
            position += 1
        }

        return generated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func unload() {
        contextHandle = nil
        sampler = nil
        modelHandle = nil
    }
}
