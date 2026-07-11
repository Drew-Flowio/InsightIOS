import XCTest
@testable import InsightCore
@testable import InsightEngine
@testable import InsightRuntime

final class InsightEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSendTextMessageStreamsIncrementalTokens() async throws {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("test.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        let engine = try InsightEngine(configuration: config)
        let collector = TurnEventCollector()

        let result = try await engine.sendTextMessage(
            "Is this safe to touch?",
            onToken: { collector.recordToken($0) },
            onState: { collector.recordState($0) }
        )

        XCTAssertFalse(result.cancelled)
        XCTAssertFalse(result.replyText.isEmpty)
        XCTAssertFalse(collector.tokens.isEmpty)
        XCTAssertEqual(collector.tokens.joined(), result.replyText)
        XCTAssertTrue(collector.states.contains(.thinking))

        let history = await engine.getHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[1].role, "assistant")
        XCTAssertEqual(history[1].content, result.replyText)
    }

    func testCancelledTurnPersistsCancelledAssistantMessage() async throws {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("cancel.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        let engine = try InsightEngine(configuration: config)

        let task = Task {
            try await engine.sendTextMessage(
                "Tell me a long story.",
                onToken: { _ in },
                onState: nil
            )
        }

        try await Task.sleep(for: .milliseconds(40))
        await engine.cancelCurrent()

        let result = try await task.value
        XCTAssertTrue(result.cancelled)

        let history = await engine.getHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[1].role, "assistant")
    }

    func testActivePersonalityIsStoredAndRetrievable() async throws {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("prompt.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        let engine = try InsightEngine(configuration: config)

        let customPrompt = "You are Offgrid Minds: steady, practical, and human."
        _ = await engine.updatePrompt(newText: customPrompt, label: "test")

        let storedPrompt = await engine.getSystemPrompt()
        XCTAssertEqual(storedPrompt, customPrompt)
    }

    func testModelCatalogPicksPhi4ProductionOn8GBDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 8_589_934_592)
        XCTAssertEqual(bundle.tier, .primary)
        XCTAssertTrue(bundle.llmFileName.contains("Phi-4"))
    }

    func testModelCatalogFallbackPreservesPhi35On8GBDevice() {
        let bundle = ModelCatalog.fallbackBundle(forPhysicalMemoryBytes: 8_589_934_592)
        XCTAssertEqual(bundle.tier, .fallbackPrimary)
        XCTAssertTrue(bundle.llmFileName.contains("Phi-3.5"))
    }

    func testModelCatalogPicksCompactForLowRAMDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 4_294_967_296)
        XCTAssertEqual(bundle.profile, .compact)
    }
}

private final class TurnEventCollector: @unchecked Sendable {
    private(set) var tokens: [String] = []
    private(set) var states: [AppState] = []

    func recordToken(_ token: String) {
        tokens.append(token)
    }

    func recordState(_ state: AppState) {
        states.append(state)
    }
}
