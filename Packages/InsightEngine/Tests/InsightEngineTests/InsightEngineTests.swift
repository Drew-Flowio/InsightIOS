import XCTest
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

    func testSendTextMessageRecordsHistoryAndStreams() async throws {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("test.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        let engine = try await InsightEngine(configuration: config)

        var tokens: [String] = []
        var states: [AppState] = []

        let result = try await engine.sendTextMessage(
            "Is this safe to touch?",
            onToken: { tokens.append($0) },
            onState: { states.append($0) }
        )

        XCTAssertFalse(result.cancelled)
        XCTAssertFalse(result.replyText.isEmpty)
        XCTAssertFalse(tokens.isEmpty)
        XCTAssertTrue(states.contains(.thinking))

        let history = await engine.getHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].role, "user")
        XCTAssertEqual(history[1].role, "assistant")
    }

    func testModelCatalogPicksPrimaryFor8GBDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 8_000_000_000)
        XCTAssertEqual(bundle.profile, .primary)
        XCTAssertTrue(bundle.llmFileName.contains("Phi-3.5"))
        XCTAssertTrue(bundle.llmFileName.contains("Q4_K_M"))
    }

    func testModelCatalogPicksEfficientPhiFor6GBDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 6_000_000_000)
        XCTAssertEqual(bundle.profile, .primary)
        XCTAssertTrue(bundle.llmFileName.contains("Q4_K_S"))
    }

    func testModelCatalogPicksCompactForLowRAMDevice() {
        let bundle = ModelCatalog.recommendedBundle(forPhysicalMemoryBytes: 4_000_000_000)
        XCTAssertEqual(bundle.profile, .compact)
    }
}
