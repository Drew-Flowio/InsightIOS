import Foundation

/// Curated on-device models for Insight on iPhone.
///
/// **Production primary:** Phi-4-mini-instruct Q4_K_M on 8 GB devices; Q4_K_S on 6 GB devices.
///
/// **Internal fallback:** Phi-3.5-mini-instruct — not exposed in customer UI.
///
/// **Compact:** Qwen2.5-1.5B-instruct — low-RAM fallback.
public enum ModelCatalog {
    public enum Profile: String, Sendable, CaseIterable, Identifiable {
        case primary
        case compact

        public var id: String { rawValue }
    }

    public enum ModelTier: String, Sendable, CaseIterable, Identifiable {
        case primary
        case fallbackPrimary
        case compact

        public var id: String { rawValue }
    }

    public struct ModelProvenance: Sendable, Equatable {
        public let originalPublisher: String
        public let ggufPublisher: String
        public let quantization: String
        public let modelLicense: String
        public let ggufNotes: String
    }

    public struct ModelBundle: Sendable, Equatable {
        public let tier: ModelTier
        public let profile: Profile
        /// Internal catalog label; customer setup copy uses `ModelCatalog.customerSetupLabel`.
        public let displayName: String
        public let license: String
        public let provenance: ModelProvenance
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
        public let visionModelDiskBytes: Int64
        public let visionMmprojDiskBytes: Int64
        public let minimumDeviceRAMGB: Int

        public var visionDownloadBytes: Int64 {
            visionModelDiskBytes + visionMmprojDiskBytes
        }

        public var totalDownloadBytes: Int64 {
            llmDiskBytes + whisperDiskBytes + visionDownloadBytes
        }
    }

    /// Customer-facing setup label — no model names or runtime details.
    public static let customerSetupLabel = "Offgrid Minds"

    private enum SharedRuntimeAssets {
        static let whisperFileName = "ggml-base.en.bin"
        static let whisperDownloadURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!
        static let whisperDiskBytes: Int64 = 147_964_211
        static let referenceVoiceFileName = "insight_reference_voice.wav"
        static let visionModelFileName = "SmolVLM-500M-Instruct-Q8_0.gguf"
        static let visionMmprojFileName = "mmproj-SmolVLM-500M-Instruct-Q8_0.gguf"
        static let visionModelDownloadURL = URL(string: "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/SmolVLM-500M-Instruct-Q8_0.gguf")!
        static let visionMmprojDownloadURL = URL(string: "https://huggingface.co/ggml-org/SmolVLM-500M-Instruct-GGUF/resolve/main/mmproj-SmolVLM-500M-Instruct-Q8_0.gguf")!
        /// Hugging Face `X-Linked-Size` for ggml-org/SmolVLM-500M-Instruct-GGUF @ 72e9860.
        static let visionModelDiskBytes: Int64 = 436_806_912
        static let visionMmprojDiskBytes: Int64 = 108_783_360
    }

    private static let phi4Provenance = ModelProvenance(
        originalPublisher: "microsoft/Phi-4-mini-instruct",
        ggufPublisher: "bartowski/microsoft_Phi-4-mini-instruct-GGUF",
        quantization: "Q4_K_M (llama.cpp imatrix)",
        modelLicense: "MIT",
        ggufNotes: "Community imatrix GGUF conversion by bartowski; inherits MIT license from the Microsoft base model."
    )

    private static let phi35Provenance = ModelProvenance(
        originalPublisher: "microsoft/Phi-3.5-mini-instruct",
        ggufPublisher: "bartowski/Phi-3.5-mini-instruct-GGUF",
        quantization: "Q4_K_M (llama.cpp imatrix)",
        modelLicense: "MIT",
        ggufNotes: "Community imatrix GGUF conversion by bartowski; inherits MIT license from the Microsoft base model."
    )

    private static let qwenProvenance = ModelProvenance(
        originalPublisher: "Qwen/Qwen2.5-1.5B-Instruct",
        ggufPublisher: "bartowski/Qwen2.5-1.5B-Instruct-GGUF",
        quantization: "Q4_K_M (llama.cpp imatrix)",
        modelLicense: "Apache-2.0",
        ggufNotes: "Community imatrix GGUF conversion by bartowski; inherits Apache-2.0 license from the Qwen base model."
    )

    /// Production Phi-4 for 8 GB iPhones.
    public static let primaryHighQuality = ModelBundle(
        tier: .primary,
        profile: .primary,
        displayName: "Phi-4-mini-instruct Q4_K_M",
        license: "MIT",
        provenance: phi4Provenance,
        llmFileName: "microsoft_Phi-4-mini-instruct-Q4_K_M.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf")!,
        llmDiskBytes: 2_491_874_688,
        llmContextLength: 1536,
        whisperFileName: SharedRuntimeAssets.whisperFileName,
        whisperDownloadURL: SharedRuntimeAssets.whisperDownloadURL,
        whisperDiskBytes: SharedRuntimeAssets.whisperDiskBytes,
        referenceVoiceFileName: SharedRuntimeAssets.referenceVoiceFileName,
        visionModelFileName: SharedRuntimeAssets.visionModelFileName,
        visionMmprojFileName: SharedRuntimeAssets.visionMmprojFileName,
        visionModelDownloadURL: SharedRuntimeAssets.visionModelDownloadURL,
        visionMmprojDownloadURL: SharedRuntimeAssets.visionMmprojDownloadURL,
        visionModelDiskBytes: SharedRuntimeAssets.visionModelDiskBytes,
        visionMmprojDiskBytes: SharedRuntimeAssets.visionMmprojDiskBytes,
        minimumDeviceRAMGB: 7
    )

    /// Production Phi-4 for 6 GB iPhones.
    public static let primaryEfficient = ModelBundle(
        tier: .primary,
        profile: .primary,
        displayName: "Phi-4-mini-instruct Q4_K_S",
        license: "MIT",
        provenance: ModelProvenance(
            originalPublisher: phi4Provenance.originalPublisher,
            ggufPublisher: phi4Provenance.ggufPublisher,
            quantization: "Q4_K_S (llama.cpp imatrix)",
            modelLicense: phi4Provenance.modelLicense,
            ggufNotes: phi4Provenance.ggufNotes
        ),
        llmFileName: "microsoft_Phi-4-mini-instruct-Q4_K_S.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_S.gguf")!,
        llmDiskBytes: 2_337_734_016,
        llmContextLength: 1536,
        whisperFileName: SharedRuntimeAssets.whisperFileName,
        whisperDownloadURL: SharedRuntimeAssets.whisperDownloadURL,
        whisperDiskBytes: SharedRuntimeAssets.whisperDiskBytes,
        referenceVoiceFileName: SharedRuntimeAssets.referenceVoiceFileName,
        visionModelFileName: SharedRuntimeAssets.visionModelFileName,
        visionMmprojFileName: SharedRuntimeAssets.visionMmprojFileName,
        visionModelDownloadURL: SharedRuntimeAssets.visionModelDownloadURL,
        visionMmprojDownloadURL: SharedRuntimeAssets.visionMmprojDownloadURL,
        visionModelDiskBytes: SharedRuntimeAssets.visionModelDiskBytes,
        visionMmprojDiskBytes: SharedRuntimeAssets.visionMmprojDiskBytes,
        minimumDeviceRAMGB: 6
    )

    public static let primary = primaryHighQuality

    /// Internal Phi-3.5 fallback for 8 GB devices.
    public static let fallbackPrimaryHighQuality = ModelBundle(
        tier: .fallbackPrimary,
        profile: .primary,
        displayName: "Phi-3.5-mini-instruct Q4_K_M (fallback)",
        license: "MIT",
        provenance: phi35Provenance,
        llmFileName: "Phi-3.5-mini-instruct-Q4_K_M.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf")!,
        llmDiskBytes: 2_393_232_672,
        llmContextLength: 1536,
        whisperFileName: SharedRuntimeAssets.whisperFileName,
        whisperDownloadURL: SharedRuntimeAssets.whisperDownloadURL,
        whisperDiskBytes: SharedRuntimeAssets.whisperDiskBytes,
        referenceVoiceFileName: SharedRuntimeAssets.referenceVoiceFileName,
        visionModelFileName: SharedRuntimeAssets.visionModelFileName,
        visionMmprojFileName: SharedRuntimeAssets.visionMmprojFileName,
        visionModelDownloadURL: SharedRuntimeAssets.visionModelDownloadURL,
        visionMmprojDownloadURL: SharedRuntimeAssets.visionMmprojDownloadURL,
        visionModelDiskBytes: SharedRuntimeAssets.visionModelDiskBytes,
        visionMmprojDiskBytes: SharedRuntimeAssets.visionMmprojDiskBytes,
        minimumDeviceRAMGB: 7
    )

    /// Internal Phi-3.5 fallback for 6 GB devices.
    public static let fallbackPrimaryEfficient = ModelBundle(
        tier: .fallbackPrimary,
        profile: .primary,
        displayName: "Phi-3.5-mini-instruct Q4_K_S (fallback)",
        license: "MIT",
        provenance: ModelProvenance(
            originalPublisher: phi35Provenance.originalPublisher,
            ggufPublisher: phi35Provenance.ggufPublisher,
            quantization: "Q4_K_S (llama.cpp imatrix)",
            modelLicense: phi35Provenance.modelLicense,
            ggufNotes: phi35Provenance.ggufNotes
        ),
        llmFileName: "Phi-3.5-mini-instruct-Q4_K_S.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_S.gguf")!,
        llmDiskBytes: 2_188_760_352,
        llmContextLength: 1536,
        whisperFileName: SharedRuntimeAssets.whisperFileName,
        whisperDownloadURL: SharedRuntimeAssets.whisperDownloadURL,
        whisperDiskBytes: SharedRuntimeAssets.whisperDiskBytes,
        referenceVoiceFileName: SharedRuntimeAssets.referenceVoiceFileName,
        visionModelFileName: SharedRuntimeAssets.visionModelFileName,
        visionMmprojFileName: SharedRuntimeAssets.visionMmprojFileName,
        visionModelDownloadURL: SharedRuntimeAssets.visionModelDownloadURL,
        visionMmprojDownloadURL: SharedRuntimeAssets.visionMmprojDownloadURL,
        visionModelDiskBytes: SharedRuntimeAssets.visionModelDiskBytes,
        visionMmprojDiskBytes: SharedRuntimeAssets.visionMmprojDiskBytes,
        minimumDeviceRAMGB: 6
    )

    /// Backward-compatible aliases for the internal fallback tier.
    public static let rollbackPrimaryHighQuality = fallbackPrimaryHighQuality
    public static let rollbackPrimaryEfficient = fallbackPrimaryEfficient

    /// Low-RAM fallback for smaller iPhones.
    public static let compact = ModelBundle(
        tier: .compact,
        profile: .compact,
        displayName: "Qwen2.5-1.5B-Instruct Q4_K_M (compact)",
        license: "Apache-2.0",
        provenance: qwenProvenance,
        llmFileName: "Qwen2.5-1.5B-Instruct-Q4_K_M.gguf",
        llmDownloadURL: URL(string: "https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf")!,
        llmDiskBytes: 986_048_768,
        llmContextLength: 1536,
        whisperFileName: SharedRuntimeAssets.whisperFileName,
        whisperDownloadURL: SharedRuntimeAssets.whisperDownloadURL,
        whisperDiskBytes: SharedRuntimeAssets.whisperDiskBytes,
        referenceVoiceFileName: SharedRuntimeAssets.referenceVoiceFileName,
        visionModelFileName: SharedRuntimeAssets.visionModelFileName,
        visionMmprojFileName: SharedRuntimeAssets.visionMmprojFileName,
        visionModelDownloadURL: SharedRuntimeAssets.visionModelDownloadURL,
        visionMmprojDownloadURL: SharedRuntimeAssets.visionMmprojDownloadURL,
        visionModelDiskBytes: SharedRuntimeAssets.visionModelDiskBytes,
        visionMmprojDiskBytes: SharedRuntimeAssets.visionMmprojDiskBytes,
        minimumDeviceRAMGB: 4
    )

    public static let allLLMBundles: [ModelBundle] = [
        primaryHighQuality,
        primaryEfficient,
        fallbackPrimaryHighQuality,
        fallbackPrimaryEfficient,
        compact,
    ]

    public static func recommendedBundle(forPhysicalMemoryBytes bytes: UInt64) -> ModelBundle {
        let ramGB = Double(bytes) / 1_073_741_824.0
        if ramGB >= 7.5 { return primaryHighQuality }
        if ramGB >= 5.5 { return primaryEfficient }
        return compact
    }

    public static func fallbackBundle(forPhysicalMemoryBytes bytes: UInt64) -> ModelBundle {
        let ramGB = Double(bytes) / 1_073_741_824.0
        if ramGB >= 7.5 { return fallbackPrimaryHighQuality }
        if ramGB >= 5.5 { return fallbackPrimaryEfficient }
        return compact
    }

    public static func rollbackBundle(forPhysicalMemoryBytes bytes: UInt64) -> ModelBundle {
        fallbackBundle(forPhysicalMemoryBytes: bytes)
    }

    public static func llmConfig(for bundle: ModelBundle) -> LlmRuntimeConfig {
        let maxTokens: Int
        if bundle.tier == .compact {
            maxTokens = 448
        } else if bundle.llmFileName.contains("Q4_K_M") {
            maxTokens = 512
        } else {
            maxTokens = 448
        }

        return LlmRuntimeConfig(
            modelFileName: bundle.llmFileName,
            contextLength: bundle.llmContextLength,
            maxTokens: maxTokens,
            batchSize: 64,
            temperature: 0.2,
            topP: 0.88,
            topK: 40,
            repeatPenalty: 1.10,
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
            modelDiskBytes: bundle.visionModelDiskBytes,
            mmprojDiskBytes: bundle.visionMmprojDiskBytes,
            maxPredictTokens: 128,
            temperature: 0.1,
            gpuLayers: -1
        )
    }

    public static let inferenceBackend = "llama.cpp (Metal)"
}
