import Foundation

/// RAM-tier residency rules for on-device LLM, Whisper, and SmolVLM.
public struct ModelResidencyPolicy: Sendable, Equatable {
    public enum DeviceMemoryTier: String, Sendable, CaseIterable {
        /// Low-RAM devices (typically &lt; 6 GB physical).
        case compact
        /// Typical iPhone class (6–12 GB physical).
        case normal
        /// Higher-memory iPhone / iPad class (≥ 12 GB physical).
        case high
    }

    public let tier: DeviceMemoryTier
    public let physicalMemoryBytes: UInt64

    public init(tier: DeviceMemoryTier, physicalMemoryBytes: UInt64) {
        self.tier = tier
        self.physicalMemoryBytes = physicalMemoryBytes
    }

    public static func current() -> ModelResidencyPolicy {
        forPhysicalMemoryBytes(ProcessInfo.processInfo.physicalMemory)
    }

    public static func forPhysicalMemoryBytes(_ bytes: UInt64) -> ModelResidencyPolicy {
        let ramGB = Double(bytes) / 1_073_741_824.0
        let tier: DeviceMemoryTier
        if ramGB >= 12.0 {
            tier = .high
        } else if ramGB >= 5.5 {
            tier = .normal
        } else {
            tier = .compact
        }
        return ModelResidencyPolicy(tier: tier, physicalMemoryBytes: bytes)
    }

    /// Preload Phi-4 / Qwen at bootstrap on normal and high tiers only.
    public var preloadsLLMAtBootstrap: Bool {
        switch tier {
        case .compact: false
        case .normal, .high: true
        }
    }

    /// Evict the reasoning model after each turn on compact devices.
    public var unloadsLLMAfterTurn: Bool {
        tier == .compact
    }

    /// Unload Whisper before SmolVLM or Phi-4 work.
    public var unloadsSTTBeforeHeavyWork: Bool { true }

    /// Unload SmolVLM before Phi-4 reasoning.
    public var unloadsVisionBeforeLLM: Bool { true }

    /// Unload Phi-4 before Whisper transcription when memory is tight.
    public var unloadsLLMBeforeSTT: Bool {
        switch tier {
        case .compact, .normal: true
        case .high: false
        }
    }

    /// Unload Phi-4 before SmolVLM photo analysis when memory is tight.
    public var unloadsLLMBeforeVision: Bool {
        switch tier {
        case .compact, .normal: true
        case .high: false
        }
    }

    /// Only one heavy model resident at a time on compact devices.
    public var enforcesMutualExclusion: Bool {
        tier == .compact
    }

    public var tierLabel: String {
        switch tier {
        case .compact: "compact"
        case .normal: "normal iPhone"
        case .high: "higher-memory iPhone"
        }
    }
}
