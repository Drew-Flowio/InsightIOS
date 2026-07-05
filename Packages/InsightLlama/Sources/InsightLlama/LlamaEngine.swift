import Foundation
import InsightRuntime
import LlamaSwift

enum LlamaBackend {
    private static let lock = NSLock()
    private static var initialized = false

    static func ensureInitialized() {
        lock.lock()
        defer { lock.unlock() }
        guard !initialized else { return }
        llama_backend_init()
        initialized = true
    }
}

final class LlamaModelHandle: @unchecked Sendable {
    let model: OpaquePointer
    let vocab: OpaquePointer
    let loadConfig: LlamaLoadConfig

    init(path: URL, loadConfig: LlamaLoadConfig) throws {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw LlamaRuntimeError.modelNotFound(path)
        }

        LlamaBackend.ensureInitialized()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = loadConfig.gpuLayers.rawValue

        guard let model = llama_model_load_from_file(path.path, modelParams) else {
            throw LlamaRuntimeError.failedToLoadModel(path)
        }

        self.model = model
        self.vocab = llama_model_get_vocab(model)
        self.loadConfig = loadConfig
    }

    deinit {
        llama_model_free(model)
    }
}

final class LlamaContextHandle: @unchecked Sendable {
    let context: OpaquePointer
    let modelHandle: LlamaModelHandle
    private var batch: llama_batch

    init(modelHandle: LlamaModelHandle) throws {
        self.modelHandle = modelHandle

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = modelHandle.loadConfig.contextLength
        contextParams.n_threads = modelHandle.loadConfig.threads
        contextParams.n_threads_batch = modelHandle.loadConfig.threads
        contextParams.n_batch = UInt32(modelHandle.loadConfig.batchSize)

        guard let context = llama_init_from_model(modelHandle.model, contextParams) else {
            throw LlamaRuntimeError.failedToCreateContext
        }

        self.context = context
        self.batch = llama_batch_init(modelHandle.loadConfig.batchSize, 0, 1)
    }

    func tokenize(_ text: String, addSpecial: Bool = true) throws -> [llama_token] {
        let maxTokens = Int32(text.utf8.count) + (addSpecial ? 2 : 0) + 8
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))

        let tokenCount = llama_tokenize(
            modelHandle.vocab,
            text,
            Int32(text.utf8.count),
            &tokens,
            maxTokens,
            addSpecial,
            true
        )

        guard tokenCount >= 0 else {
            throw LlamaRuntimeError.tokenizationFailed
        }

        tokens.removeSubrange(Int(tokenCount)..<tokens.count)
        return tokens
    }

    func clearBatch() {
        batch.n_tokens = 0
    }

    func addTokenToBatch(_ token: llama_token, position: Int32, logits: Bool) {
        let index = Int(batch.n_tokens)
        batch.token[index] = token
        batch.pos[index] = position
        batch.n_seq_id[index] = 1
        batch.seq_id[index]![0] = 0
        batch.logits[index] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    func decode() throws {
        let status = llama_decode(context, batch)
        guard status == 0 else {
            if status == 1 {
                throw LlamaRuntimeError.kvCacheFull
            }
            throw LlamaRuntimeError.decodingFailed(status)
        }
    }

    func tokenToString(_ token: llama_token) -> [CChar] {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = llama_token_to_piece(modelHandle.vocab, token, &buffer, Int32(buffer.count), 0, true)
        if length > 0 {
            buffer.removeSubrange(Int(length)..<buffer.count)
        } else {
            buffer.removeAll()
        }
        return buffer
    }

    func isEndOfGeneration(_ token: llama_token) -> Bool {
        llama_vocab_is_eog(modelHandle.vocab, token)
    }

    deinit {
        llama_batch_free(batch)
        llama_free(context)
    }
}

final class LlamaSamplerChain: @unchecked Sendable {
    let sampler: UnsafeMutablePointer<llama_sampler>

    init(sampling: InferenceSampling) {
        let chainParams = llama_sampler_chain_default_params()
        let chain = llama_sampler_chain_init(chainParams)!

        if sampling.repeatPenalty != 1.0 {
            llama_sampler_chain_add(
                chain,
                llama_sampler_init_penalties(64, sampling.repeatPenalty, 0.0, 0.0)
            )
        }

        if sampling.topK > 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(sampling.topK))
        }

        if sampling.topP < 1.0 {
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(sampling.topP, 1))
        }

        if sampling.temperature > 0 {
            llama_sampler_chain_add(chain, llama_sampler_init_temp(sampling.temperature))
            llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0..<UInt32.max)))
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        }

        sampler = chain
    }

    func sample(context: OpaquePointer) -> llama_token {
        llama_sampler_sample(sampler, context, -1)
    }

    func reset() {
        llama_sampler_reset(sampler)
    }

    deinit {
        llama_sampler_free(sampler)
    }
}
