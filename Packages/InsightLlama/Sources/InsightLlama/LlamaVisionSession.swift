import Foundation
import InsightCore
import InsightRuntime
import LlamaSwift

public enum LlamaVisionError: Error, LocalizedError {
    case modelsMissing
    case loadFailed(String)
    case inferenceFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .modelsMissing:
            return "SmolVLM vision model files are not installed."
        case .loadFailed(let message):
            return "Failed to load SmolVLM: \(message)"
        case .inferenceFailed(let message):
            return "SmolVLM inference failed: \(message)"
        case .cancelled:
            return "SmolVLM inference was cancelled."
        }
    }
}

/// SmolVLM inference via llama.cpp mtmd + mmproj. Load/unload is coordinated by `ModelRuntimeCoordinator`.
public actor LlamaVisionSession {
    private let modelPath: URL
    private let mmprojPath: URL
    private let config: VisionRuntimeConfig

    private var modelHandle: LlamaModelHandle?
    private var contextHandle: LlamaContextHandle?
    private var mtmdContext: OpaquePointer?
    private var sampler: LlamaSamplerChain?

    public init(modelPath: URL, mmprojPath: URL, config: VisionRuntimeConfig) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.config = config
    }

    public static func modelsAvailable(modelPath: URL, mmprojPath: URL) -> Bool {
        FileManager.default.fileExists(atPath: modelPath.path) &&
            FileManager.default.fileExists(atPath: mmprojPath.path)
    }

    public var isLoaded: Bool {
        modelHandle != nil && mtmdContext != nil
    }

    public func prepareForInference() throws {
        try prepareIfNeeded()
    }

    public func generateObservationsJSON(imageURL: URL) throws -> String {
        guard Self.modelsAvailable(modelPath: modelPath, mmprojPath: mmprojPath) else {
            throw LlamaVisionError.modelsMissing
        }

        try prepareIfNeeded()

        guard let modelHandle, let contextHandle, let mtmdContext else {
            throw LlamaVisionError.loadFailed("Vision runtime was not initialized.")
        }

        var wrapper = mtmd_helper_bitmap_init_from_file(mtmdContext, imageURL.path, false)
        defer {
            if let bitmap = wrapper.bitmap {
                mtmd_bitmap_free(bitmap)
            }
        }
        guard wrapper.bitmap != nil else {
            throw LlamaVisionError.inferenceFailed("Could not decode image for SmolVLM.")
        }

        let marker = String(cString: mtmd_default_marker())
        let prompt = """
        Analyze the image and reply with ONLY valid JSON using this shape:
        {"visibleObjects":["..."],"readableLabels":["..."],"possibleProblems":["..."],"confidence":"low|medium|high","needsAnotherAngle":true|false,"summary":"..."}
        Focus on visible objects, parts, labels, wiring, gauges, damage, and readable text. Do not invent details.
        \(marker)
        """

        guard let chunks = mtmd_input_chunks_init() else {
            throw LlamaVisionError.inferenceFailed("Could not allocate mtmd input chunks.")
        }
        defer { mtmd_input_chunks_free(chunks) }

        let tokenizeStatus = prompt.withCString { promptCString in
            var inputText = mtmd_input_text(
                text: promptCString,
                add_special: true,
                parse_special: true
            )
            var bitmap = wrapper.bitmap
            return withUnsafeMutablePointer(to: &bitmap) { bitmaps in
                mtmd_tokenize(mtmdContext, chunks, &inputText, bitmaps, 1)
            }
        }
        guard tokenizeStatus == 0 else {
            throw LlamaVisionError.inferenceFailed("SmolVLM tokenize failed with code \(tokenizeStatus).")
        }

        var nPast: llama_pos = 0
        let batchSize = Int32(modelHandle.loadConfig.batchSize)
        let evalStatus = mtmd_helper_eval_chunks(
            mtmdContext,
            contextHandle.context,
            chunks,
            nPast,
            0,
            batchSize,
            true,
            &nPast
        )
        guard evalStatus == 0 else {
            throw LlamaVisionError.inferenceFailed("SmolVLM eval failed with code \(evalStatus).")
        }

        let visionRuntime = LlmRuntimeConfig(
            modelFileName: modelPath.lastPathComponent,
            contextLength: 2048,
            maxTokens: config.maxPredictTokens,
            batchSize: 64,
            temperature: config.temperature,
            topP: 0.9,
            topK: 40,
            repeatPenalty: 1.1,
            gpuLayers: config.gpuLayers
        )
        sampler = LlamaSamplerChain(sampling: InferenceSampling(from: visionRuntime))
        guard let sampler else {
            throw LlamaVisionError.inferenceFailed("Could not create sampler.")
        }

        var generated = ""
        var position = nPast
        let maxTokens = config.maxPredictTokens

        for _ in 0..<maxTokens {
            let token = sampler.sample(context: contextHandle.context)
            if contextHandle.isEndOfGeneration(token) {
                break
            }

            let bytes = contextHandle.tokenToString(token)
            let piece = String(decoding: bytes.map { UInt8(bitPattern: $0) }.prefix { $0 != 0 }, as: UTF8.self)
            if !piece.isEmpty {
                generated += piece
            }

            contextHandle.clearBatch()
            contextHandle.addTokenToBatch(token, position: position, logits: true)
            try contextHandle.decode()
            position += 1

            if generated.contains("}") && generated.contains("{") {
                if VisualObservationsParser().parse(generated) != nil {
                    break
                }
            }
        }

        let trimmed = generated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw LlamaVisionError.inferenceFailed("SmolVLM returned an empty response.")
        }
        return trimmed
    }

    public func unload() {
        if let mtmdContext {
            mtmd_free(mtmdContext)
            self.mtmdContext = nil
        }
        contextHandle = nil
        sampler = nil
        modelHandle = nil
    }

    private func prepareIfNeeded() throws {
        if modelHandle != nil, mtmdContext != nil {
            return
        }

        LlamaBackend.ensureInitialized()

        let loadConfig = LlamaLoadConfig(
            from: LlmRuntimeConfig(
                modelFileName: modelPath.lastPathComponent,
                contextLength: 2048,
                maxTokens: config.maxPredictTokens,
                temperature: config.temperature,
                topP: 0.9,
                topK: 40,
                repeatPenalty: 1.1,
                gpuLayers: config.gpuLayers
            ),
            forceCPU: false,
            fallbackReason: nil
        )

        let model = try LlamaModelHandle(path: modelPath, loadConfig: loadConfig)
        let context = try LlamaContextHandle(modelHandle: model)

        var params = mtmd_context_params_default()
        params.use_gpu = loadConfig.gpuLayers.usesGPU
        params.n_threads = Int32(loadConfig.threads)
        params.warmup = false

        guard let mtmd = mtmd_init_from_file(mmprojPath.path, model.model, params) else {
            throw LlamaVisionError.loadFailed("mtmd_init_from_file returned nil.")
        }
        guard mtmd_support_vision(mtmd) else {
            mtmd_free(mtmd)
            throw LlamaVisionError.loadFailed("Loaded mmproj does not support vision.")
        }

        self.modelHandle = model
        self.contextHandle = context
        self.mtmdContext = mtmd
    }
}
