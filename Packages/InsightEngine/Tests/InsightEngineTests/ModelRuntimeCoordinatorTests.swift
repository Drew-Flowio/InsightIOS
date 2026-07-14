import XCTest
@testable import InsightCore
@testable import InsightEngine
@testable import InsightRuntime

final class ModelRuntimeCoordinatorTests: XCTestCase {
    func testAcquireVisionUnloadsLLMOnNormalTier() async throws {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = RecordingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .normal, physicalMemoryBytes: 8_589_934_592)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        try await llm.prepare()
        try await coordinator.acquireVision()

        XCTAssertEqual(llm.events, ["prepare", "unload"])
        XCTAssertEqual(vision.events, ["prepare"])
        let visionLoaded = await vision.isLoaded
        XCTAssertTrue(visionLoaded)
    }

    func testAcquireLLMUnloadsVisionAndSTT() async throws {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = RecordingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .normal, physicalMemoryBytes: 8_589_934_592)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        try await stt.prepare()
        try await vision.prepare()
        try await coordinator.acquireLLM()

        XCTAssertEqual(stt.events, ["prepare", "unload"])
        XCTAssertEqual(vision.events, ["prepare", "unload"])
        XCTAssertEqual(llm.events, ["prepare"])
    }

    func testCompactTierEnforcesMutualExclusion() async throws {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = RecordingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .compact, physicalMemoryBytes: 4_294_967_296)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        try await llm.prepare()
        try await coordinator.acquireSTT()

        XCTAssertEqual(llm.events, ["prepare", "unload"])
        XCTAssertEqual(stt.events, ["prepare"])
    }

    func testHighTierKeepsLLMDuringSTT() async throws {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = RecordingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .high, physicalMemoryBytes: 12_884_901_888)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        try await llm.prepare()
        try await coordinator.acquireSTT()

        XCTAssertEqual(llm.events, ["prepare"])
        XCTAssertEqual(stt.events, ["prepare"])
    }

    func testReusesLoadedLLMWithoutReload() async throws {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = RecordingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .high, physicalMemoryBytes: 12_884_901_888)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        try await llm.prepare()
        try await coordinator.acquireLLM()

        XCTAssertEqual(llm.events, ["prepare"])
    }

    func testAcquireVisionSurfacesCustomerNoticeWhenPrepareFails() async {
        let llm = RecordingModelAdapter(slot: .llm)
        let stt = RecordingModelAdapter(slot: .stt)
        let vision = FailingVisionAdapter()
        let policy = ModelResidencyPolicy(tier: .normal, physicalMemoryBytes: 8_589_934_592)
        let coordinator = ModelRuntimeCoordinator(policy: policy, llm: llm, stt: stt, vision: vision)

        do {
            try await coordinator.acquireVision()
            XCTFail("Expected acquireVision to fail")
        } catch let error as ModelRuntimeCoordinator.Error {
            XCTAssertTrue(error.localizedDescription.contains("Text recognition still works"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum RecordingSlot {
    case llm
    case stt
}

private final class RecordingModelAdapter: LlmServing, SttServing, @unchecked Sendable {
    let slot: RecordingSlot
    private(set) var events: [String] = []
    private var loaded = false

    init(slot: RecordingSlot) {
        self.slot = slot
    }

    func prepare() async throws {
        events.append("prepare")
        loaded = true
    }

    func unload() async {
        events.append("unload")
        loaded = false
    }

    var isLoaded: Bool {
        get async { loaded }
    }

    func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) async throws -> String {
        _ = messages
        _ = onToken
        _ = shouldCancel
        return "ok"
    }

    func transcribe(audioURL: URL) async throws -> String {
        _ = audioURL
        return "transcript"
    }
}

private final class RecordingVisionAdapter: VisionModelServing, @unchecked Sendable {
    private(set) var events: [String] = []
    private var loaded = false

    var supportsVisualReasoning: Bool { get async { true } }

    var isLoaded: Bool { get async { loaded } }

    func prepare() async throws {
        events.append("prepare")
        loaded = true
    }

    func unload() async {
        events.append("unload")
        loaded = false
    }

    func analyzePhoto(at imageURL: URL) async throws -> PhotoAnalysisResult {
        try await analyzePhoto(at: imageURL, includeVisualReasoning: true)
    }

    func analyzePhoto(at imageURL: URL, includeVisualReasoning: Bool) async throws -> PhotoAnalysisResult {
        _ = includeVisualReasoning
        return PhotoAnalysisResult(
            imagePath: imageURL.path,
            width: 100,
            height: 100,
            ocrText: "OCR",
            visionAnalysisSource: .ocrOnly
        )
    }

    func describeImage(at imageURL: URL) async throws -> String {
        _ = imageURL
        return "desc"
    }
}

private final class FailingVisionAdapter: VisionModelServing, @unchecked Sendable {
    var supportsVisualReasoning: Bool { get async { true } }
    var isLoaded: Bool { get async { false } }

    func prepare() async throws {
        throw ModelRuntimeCoordinator.Error.featureTemporarilyUnavailable(
            "Visual reasoning is temporarily unavailable. Text recognition still works."
        )
    }

    func unload() async {}

    func analyzePhoto(at imageURL: URL) async throws -> PhotoAnalysisResult {
        try await analyzePhoto(at: imageURL, includeVisualReasoning: true)
    }

    func analyzePhoto(at imageURL: URL, includeVisualReasoning: Bool) async throws -> PhotoAnalysisResult {
        _ = includeVisualReasoning
        return PhotoAnalysisResult(
            imagePath: imageURL.path,
            width: 100,
            height: 100,
            ocrText: "OCR",
            visionAnalysisSource: .vlmUnavailable
        )
    }

    func describeImage(at imageURL: URL) async throws -> String {
        _ = imageURL
        return "desc"
    }
}
