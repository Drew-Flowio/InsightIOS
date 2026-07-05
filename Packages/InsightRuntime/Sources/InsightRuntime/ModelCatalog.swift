import Foundation

/// Curated on-device models for Insight on iPhone.
///
/// Selection criteria (matching `docs/01-model-choice.md`):
/// - Permissive license only (MIT / Apache-2.0)
/// - Practical reasoning for hands-on safety Q&A
/// - Fits iPhone RAM with sequential model loading (LLM ↔ vision ↔ STT never all resident)
///
/// **Primary:** Phi-3.5-mini-instruct Q4_K_M on 8 GB devices for the best reasoning quality.
/// Uses Q4_K_S on 6 GB devices for smoother inference.
///
/// **Compact:** Qwen2.5-1.5B-instruct — Apache-2.0 fallback for 6 GB devices. Faster, slightly
/// shallower reasoning. Do **not** use Qwen2.5-3B (research license only).
public enum ModelCatalog {
    public enum Profile: String, Sendable, CaseIterable, Identifiable {
        case primary
        case compact

        public var id: String { rawValue }
    }

    public struct ModelBundle: Sendable, Equatable {
        public let profile: Profile
        public let displayName: String
        public let license: String
        public let llmFileName: String
        public let llmDownloadURL: URL
        public let llmDiskBytes: Int64
        public let llmContextLength: Int
        public let whisperFileName: String
        public let whisperDownloadURL: URL
        public let whisperDiskBytes: Int64
        /// Bundled / setup-generated reference clip for Coqui XTTS on macOS.
        public let referenceVoiceFileName: String
        public let visionModelFileName: String
        public let visionMmprojFileName: String
        public let visionModelDownloadURL: URL
        public let visionMmprojDownloadURL: URL
        public let minimumDeviceRAMGB: Int

        public var totalDownloadBytes: Int64 {
            llmDiskBytes + whisperDiskBytes + 250_000_000 + 250_000_000
        }
    }

    /// Best conversational quality on iPhone 15 Pro / 16 (8 GB).
    public static let primaryHighQuality = ModelBundle(
        profile: .primary,
        displayName: "Phi-3.5 Mini (best quality)",
        license: "MIT",
        llmFileName: "Phi-3.5-mini-instruct-Q4_K_M.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf")!,
        llmDiskBytes: 2_400_000_000,
        llmContextLength: 3072,
        whisperFileName: "ggml-base.en.bin",
        whisperDownloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!,
        whisperDiskBytes: 148_000_000,
        referenceVoiceFileName: "insight_reference_voice.wav",
        visionModelFileName: "SmolVLM-500M-Instruct-Q8_0.gguf",
        visionMmprojFileName: "mmproj-SmolVLM-500M-Instruct-Q8_0.gguf",
        visionModelDownloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolVLM-500M-Instruct-gguf/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf")!,
        visionMmprojDownloadURL: URL(string: "https://huggingface.co/HuggingFaceTB/SmolVLM-500M-Instruct-gguf/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf")!,
        minimumDeviceRAMGB: 7
    )

    /// Faster variant for 6 GB iPhones while staying on Phi-3.5.
    public static let primaryEfficient = ModelBundle(
        profile: .primary,
        displayName: "Phi-3.5 Mini (efficient)",
        license: "MIT",
        llmFileName: "Phi-3.5-mini-instruct-Q4_K_S.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_S.gguf")!,
        llmDiskBytes: 2_100_000_000,
        llmContextLength: 2048,
        whisperFileName: primaryHighQuality.whisperFileName,
        whisperDownloadURL: primaryHighQuality.whisperDownloadURL,
        whisperDiskBytes: primaryHighQuality.whisperDiskBytes,
        referenceVoiceFileName: primaryHighQuality.referenceVoiceFileName,
        visionModelFileName: primaryHighQuality.visionModelFileName,
        visionMmprojFileName: primaryHighQuality.visionMmprojFileName,
        visionModelDownloadURL: primaryHighQuality.visionModelDownloadURL,
        visionMmprojDownloadURL: primaryHighQuality.visionMmprojDownloadURL,
        minimumDeviceRAMGB: 6
    )

    /// Backward-compatible alias.
    public static let primary = primaryHighQuality

    /// Faster fallback for 6 GB iPhones (iPhone 13/14 base, etc.).
    public static let compact = ModelBundle(
        profile: .compact,
        displayName: "Qwen2.5 1.5B (compact)",
        license: "Apache-2.0",
        llmFileName: "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf")!,
        llmDiskBytes: 1_000_000_000,
        llmContextLength: 2048,
        whisperFileName: primaryHighQuality.whisperFileName,
        whisperDownloadURL: primaryHighQuality.whisperDownloadURL,
        whisperDiskBytes: primaryHighQuality.whisperDiskBytes,
        referenceVoiceFileName: primaryHighQuality.referenceVoiceFileName,
        visionModelFileName: primaryHighQuality.visionModelFileName,
        visionMmprojFileName: primaryHighQuality.visionMmprojFileName,
        visionModelDownloadURL: primaryHighQuality.visionModelDownloadURL,
        visionMmprojDownloadURL: primaryHighQuality.visionMmprojDownloadURL,
        minimumDeviceRAMGB: 4
    )

    public static func recommendedBundle(forPhysicalMemoryBytes bytes: UInt64) -> ModelBundle {
        let ramGB = Double(bytes) / 1_073_741_824.0
        if ramGB >= 7.5 { return primaryHighQuality }
        if ramGB >= 5.5 { return primaryEfficient }
        return compact
    }

    public static func llmConfig(for bundle: ModelBundle) -> LlmRuntimeConfig {
        let isHighQuality = bundle.llmFileName.contains("Q4_K_M")
        return LlmRuntimeConfig(
            modelFileName: bundle.llmFileName,
            contextLength: bundle.llmContextLength,
            maxTokens: isHighQuality ? 320 : 256,
            temperature: 0.62,
            topP: 0.90,
            topK: 50,
            repeatPenalty: 1.08,
            gpuLayers: -1
        )
    }

    public static func sttConfig(for bundle: ModelBundle) -> SttRuntimeConfig {
        SttRuntimeConfig(modelFileName: bundle.whisperFileName)
    }

    public static func ttsConfig(for bundle: ModelBundle) -> TtsRuntimeConfig {
        TtsRuntimeConfig(referenceVoiceFileName: bundle.referenceVoiceFileName)
    }

    public static func visionConfig(for bundle: ModelBundle) -> VisionRuntimeConfig {
        VisionRuntimeConfig(
            modelFileName: bundle.visionModelFileName,
            mmprojFileName: bundle.visionMmprojFileName,
            maxPredictTokens: 128,
            temperature: 0.1,
            gpuLayers: -1
        )
    }

    /// Runtime target for Step 4+ llama.cpp integration.
    public static let inferenceBackend = "llama.cpp (Metal)"
}
