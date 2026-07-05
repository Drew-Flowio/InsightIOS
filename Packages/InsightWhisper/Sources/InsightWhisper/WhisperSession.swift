import Foundation
import whisper

public actor WhisperSession {
    private let modelPath: URL
    private var context: OpaquePointer?

    public init(modelPath: URL) {
        self.modelPath = modelPath
    }

    public func prepare() throws {
        if context != nil { return }
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw WhisperRuntimeError.modelNotFound(modelPath)
        }

        var params = whisper_context_default_params()
#if targetEnvironment(simulator)
        params.use_gpu = false
#else
        params.use_gpu = true
        params.flash_attn = true
#endif

        guard let loaded = whisper_init_from_file_with_params(modelPath.path, params) else {
            throw WhisperRuntimeError.failedToLoadModel
        }
        context = loaded
    }

    public func transcribe(audioURL: URL, language: String = "en") throws -> String {
        try prepare()
        guard let context else {
            throw WhisperRuntimeError.failedToLoadModel
        }

        let samples = try WavLoader.loadMonoFloatSamples(from: audioURL)
        guard !samples.isEmpty else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.no_context = true
        params.single_segment = true
        params.n_threads = Int32(max(1, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))

        let status: Int32 = language.withCString { languageCString in
            params.language = languageCString
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard status == 0 else {
            throw WhisperRuntimeError.transcriptionFailed
        }

        var transcript = ""
        let segmentCount = whisper_full_n_segments(context)
        for index in 0..<segmentCount {
            if let cString = whisper_full_get_segment_text(context, index) {
                transcript += String(cString: cString)
            }
        }
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func unload() {
        if let context {
            whisper_free(context)
        }
        context = nil
    }

    deinit {
        if let context {
            whisper_free(context)
        }
    }
}

public struct WhisperSttAdapter: SttServing, Sendable {
    private let session: WhisperSession

    public init(modelPath: URL) {
        session = WhisperSession(modelPath: modelPath)
    }

    public func prepare() async throws {
        try await session.prepare()
    }

    public func transcribe(audioURL: URL) async throws -> String {
        try await session.transcribe(audioURL: audioURL)
    }
}
