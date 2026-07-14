import Foundation
import InsightRuntime

public enum ModelRuntimeSlot: String, Sendable, CaseIterable {
    case llm
    case stt
    case vision
}

/// Serializes heavy model residency so Whisper, SmolVLM, and Phi-4 do not fight for RAM.
public actor ModelRuntimeCoordinator {
    public enum Error: Swift.Error, LocalizedError {
        case featureTemporarilyUnavailable(String)

        public var errorDescription: String? {
            switch self {
            case .featureTemporarilyUnavailable(let message):
                message
            }
        }
    }

    private let policy: ModelResidencyPolicy
    private let llm: any LlmServing
    private let stt: any SttServing
    private let vision: (any VisionModelServing)?

    private var pendingNotice: String?
    private var activeLoads: Set<ModelRuntimeSlot> = []

    public init(
        policy: ModelResidencyPolicy,
        llm: any LlmServing,
        stt: any SttServing,
        vision: (any VisionModelServing)?
    ) {
        self.policy = policy
        self.llm = llm
        self.stt = stt
        self.vision = vision
    }

    public var residencyPolicy: ModelResidencyPolicy { policy }

    public func consumeNotice() -> String? {
        defer { pendingNotice = nil }
        return pendingNotice
    }

    public func acquireLLM() async throws {
        try await waitForExclusiveLoad(of: .llm)
        defer { activeLoads.remove(.llm) }

        if policy.unloadsSTTBeforeHeavyWork {
            await unloadSTTIfLoaded()
        }
        if policy.unloadsVisionBeforeLLM {
            await unloadVisionIfLoaded()
        }
        if policy.enforcesMutualExclusion {
            await unloadAllExcept(.llm)
        }

        if await llm.isLoaded {
            return
        }

        activeLoads.insert(.llm)
        try await llm.prepare()
    }

    public func releaseLLMAfterTurnIfNeeded() async {
        guard policy.unloadsLLMAfterTurn else { return }
        await llm.unload()
    }

    public func acquireSTT() async throws {
        try await waitForExclusiveLoad(of: .stt)
        defer { activeLoads.remove(.stt) }

        if policy.unloadsVisionBeforeLLM {
            await unloadVisionIfLoaded()
        }
        if policy.unloadsLLMBeforeSTT {
            await unloadLLMIfLoaded()
        }
        if policy.enforcesMutualExclusion {
            await unloadAllExcept(.stt)
        }

        if await stt.isLoaded {
            return
        }

        activeLoads.insert(.stt)
        try await stt.prepare()
    }

    public func releaseSTT() async {
        await stt.unload()
    }

    public func acquireVision() async throws {
        guard let vision else {
            throw Error.featureTemporarilyUnavailable(
                "Visual reasoning is not available on this device right now."
            )
        }

        try await waitForExclusiveLoad(of: .vision)
        defer { activeLoads.remove(.vision) }

        guard await vision.supportsVisualReasoning else {
            pendingNotice = "Visual reasoning is not installed. Text recognition still works."
            throw Error.featureTemporarilyUnavailable(pendingNotice!)
        }

        if policy.unloadsSTTBeforeHeavyWork {
            await unloadSTTIfLoaded()
        }
        if policy.unloadsLLMBeforeVision {
            await unloadLLMIfLoaded()
        }
        if policy.enforcesMutualExclusion {
            await unloadAllExcept(.vision)
        }

        if await vision.isLoaded {
            return
        }

        activeLoads.insert(.vision)
        do {
            try await vision.prepare()
        } catch {
            pendingNotice = "Visual reasoning is temporarily unavailable. Text recognition still works."
            throw Error.featureTemporarilyUnavailable(pendingNotice!)
        }
    }

    public func releaseVision() async {
        await vision?.unload()
    }

    public func evictAllHeavyModels() async {
        await unloadVisionIfLoaded()
        await unloadSTTIfLoaded()
        await llm.unload()
    }

    // MARK: - Private

    private func waitForExclusiveLoad(of slot: ModelRuntimeSlot) async throws {
        var spins = 0
        while activeLoads.contains(where: { $0 != slot }) {
            spins += 1
            if spins > 400 {
                throw Error.featureTemporarilyUnavailable(
                    "The assistant is preparing memory. Try again in a moment."
                )
            }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func unloadAllExcept(_ slot: ModelRuntimeSlot) async {
        if slot != .llm { await unloadLLMIfLoaded() }
        if slot != .stt { await unloadSTTIfLoaded() }
        if slot != .vision { await unloadVisionIfLoaded() }
    }

    private func unloadLLMIfLoaded() async {
        guard await llm.isLoaded else { return }
        await llm.unload()
    }

    private func unloadSTTIfLoaded() async {
        guard await stt.isLoaded else { return }
        await stt.unload()
    }

    private func unloadVisionIfLoaded() async {
        guard let vision, await vision.isLoaded else { return }
        await vision.unload()
    }
}
