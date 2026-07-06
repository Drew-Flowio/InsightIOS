import Foundation
import InsightCore
import InsightRuntime

/// Loads Phi-3.5 once and runs streaming chat inference with the selected llama.cpp backend.
public actor LlamaSession {
    private let modelPath: URL
    private var runtimeConfig: LlmRuntimeConfig
    private var backendSelection: LlamaBackendSelection
    private var modelHandle: LlamaModelHandle?
    private var contextHandle: LlamaContextHandle?
    private var sampler: LlamaSamplerChain?
    private var turnCount = 0

    public init(modelPath: URL, runtimeConfig: LlmRuntimeConfig) {
        self.init(modelPath: modelPath, backendSelection: LlamaBackendSelection.select(from: runtimeConfig))
    }

    public init(modelPath: URL, backendSelection: LlamaBackendSelection) {
        self.modelPath = modelPath
        self.runtimeConfig = backendSelection.runtimeConfig
        self.backendSelection = backendSelection
        LlamaRuntimeLog.info("Selected \(backendSelection.debugDescription)")
    }

    public var backendDebugDescription: String {
        backendSelection.debugDescription
    }

    public func prepare() throws {
        if modelHandle != nil {
            LlamaRuntimeLog.info("prepare skipped; model is already loaded and context will be rebuilt per turn.")
            return
        }

        let loadConfig = LlamaLoadConfig(from: runtimeConfig, fallbackReason: backendSelection.fallbackReason)
        do {
            try loadRuntime(with: loadConfig)
        } catch {
            guard loadConfig.gpuLayers.usesGPU else { throw error }
            LlamaRuntimeLog.info("GPU-backed llama.cpp initialization failed; retrying with CPU fallback. Reason: \(error.localizedDescription)")
            runtimeConfig = runtimeConfig.replacingGPULayers(with: 0)
            backendSelection = LlamaBackendSelection(
                runtimeConfig: runtimeConfig,
                backendName: "llama.cpp CPU",
                fallbackReason: "Metal GPU offload disabled after a failed GPU initialization attempt: \(error.localizedDescription)"
            )
            try loadRuntime(with: LlamaLoadConfig(from: runtimeConfig, forceCPU: true, fallbackReason: backendSelection.fallbackReason))
        }
    }

    private func loadRuntime(with loadConfig: LlamaLoadConfig) throws {
        let model = try LlamaModelHandle(path: modelPath, loadConfig: loadConfig)
        self.modelHandle = model
        try rebuildContext(for: model, reason: "initial load")
    }

    private func rebuildContext(for modelHandle: LlamaModelHandle, reason: String) throws {
        if contextHandle != nil || sampler != nil {
            LlamaRuntimeLog.info("Tearing down llama context before \(reason).")
        }

        contextHandle = nil
        sampler = nil

        let context = try LlamaContextHandle(modelHandle: modelHandle)
        let sampler = LlamaSamplerChain(sampling: InferenceSampling(from: runtimeConfig))

        self.contextHandle = context
        self.sampler = sampler
        LlamaRuntimeLog.info("Created llama context for \(reason).")
    }

    public func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) throws -> String {
        try prepare()

        guard let modelHandle else {
            throw LlamaRuntimeError.failedToCreateContext(nil)
        }

        turnCount += 1
        let turnID = turnCount
        LlamaRuntimeLog.info("Turn \(turnID) starting with \(messages.count) message(s).")

        do {
            try rebuildContext(for: modelHandle, reason: "turn \(turnID)")

            guard let contextHandle, let sampler else {
                throw LlamaRuntimeError.failedToCreateContext(nil)
            }

            sampler.reset()

            let prompt = try ChatPromptFormatter.formatPrompt(messages: messages, model: modelHandle.model)
            let promptTokens = try contextHandle.tokenize(prompt)
            let contextCapacity = Int(modelHandle.loadConfig.contextLength)
            let availableGenerationTokens = contextCapacity - promptTokens.count - 1
            let maxGeneratedTokens = min(runtimeConfig.maxTokens, max(0, availableGenerationTokens))

            LlamaRuntimeLog.info(
                "Turn \(turnID) prompt ready: chars=\(prompt.count), tokens=\(promptTokens.count), context=\(contextCapacity), maxGeneratedTokens=\(maxGeneratedTokens)."
            )

            guard maxGeneratedTokens > 0 else {
                throw LlamaRuntimeError.kvCacheFull
            }

            var promptTokenIndex = 0
            while promptTokenIndex < promptTokens.count {
                contextHandle.clearBatch()

                let chunkCount = min(
                    Int(modelHandle.loadConfig.batchSize),
                    promptTokens.count - promptTokenIndex
                )

                for offset in 0..<chunkCount {
                    let tokenIndex = promptTokenIndex + offset
                    contextHandle.addTokenToBatch(
                        promptTokens[tokenIndex],
                        position: Int32(tokenIndex),
                        logits: tokenIndex == promptTokens.count - 1
                    )
                }

                try contextHandle.decode()
                promptTokenIndex += chunkCount
            }
            LlamaRuntimeLog.info("Turn \(turnID) prompt decoded; generation loop starting.")

            var generated = ""
            var generatedTokenCount = 0
            var position = Int32(promptTokens.count)
            var pendingUTF8: [CChar] = []

            for _ in 0..<maxGeneratedTokens {
                if shouldCancel?() == true {
                    throw LlamaRuntimeError.cancelled
                }

                let token = sampler.sample(context: contextHandle.context)
                if contextHandle.isEndOfGeneration(token) {
                    LlamaRuntimeLog.info("Turn \(turnID) reached end-of-generation token after \(generatedTokenCount) token(s).")
                    break
                }

                generatedTokenCount += 1
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

            let trimmed = generated.trimmingCharacters(in: .whitespacesAndNewlines)
            LlamaRuntimeLog.info(
                "Turn \(turnID) completed: generatedTokens=\(generatedTokenCount), outputChars=\(trimmed.count)."
            )
            return trimmed
        } catch {
            LlamaRuntimeLog.info("Turn \(turnID) failed: \(error.localizedDescription)")
            throw error
        }
    }

    public func unload() {
        LlamaRuntimeLog.info("Unloading llama context, sampler, and model.")
        contextHandle = nil
        sampler = nil
        modelHandle = nil
    }
}
