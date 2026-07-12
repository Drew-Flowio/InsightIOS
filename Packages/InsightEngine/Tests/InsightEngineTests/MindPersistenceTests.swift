import XCTest
@testable import InsightCore
@testable import InsightEngine
@testable import InsightStorage

final class MindPersistenceTests: XCTestCase {
    private var repository: Repository!

    override func setUpWithError() throws {
        repository = try Repository.inMemory()
    }

    func testBundledMindInstallsAndRetrievesOnQuestion() throws {
        MindBootstrap.seedBundledMindsIfNeeded(in: repository)

        let installed = repository.listEnabledKnowledgeVolumes()
        XCTAssertEqual(installed.count, 1)
        XCTAssertEqual(installed.first?.id, "mind.florida-coastal-demo")

        let volumes = MindBootstrap.enabledVolumes(from: repository)
        let retrieved = KnowledgeRetriever().retrieve(
            query: "weak telltale stream outboard cooling",
            volumes: volumes
        )

        XCTAssertEqual(retrieved.hits.first?.recordID, "outboard.telltale.weak-stream")
    }

    func testAssistantMessagePersistsKnowledgeSources() throws {
        MindBootstrap.seedBundledMindsIfNeeded(in: repository)
        var sessionManager = SessionManager(repository: repository, historyTurnsInPrompt: 4)

        _ = sessionManager.recordUserMessage(text: "Tell me about the telltale stream.")
        let source = KnowledgeSourceAttribution(
            volumeID: "mind.florida-coastal-demo",
            volumeTitle: "Florida Coastal",
            recordID: "outboard.telltale.weak-stream",
            recordTitle: "Weak or intermittent telltale stream",
            excerpt: "A healthy outboard telltale should produce a steady stream..."
        )
        let assistant = sessionManager.recordAssistantMessage(
            text: "Check the telltale outlet first.",
            promptVersionID: nil,
            latencyMs: 10,
            knowledgeSources: [source]
        )

        let stored = repository.listMessageKnowledgeSources(messageID: assistant.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.recordID, "outboard.telltale.weak-stream")
    }

    func testMultipleEnabledMindsAreSupportedInDataModel() throws {
        MindBootstrap.install(
            volume: KnowledgeVolume(
                id: "mind.sample-a",
                title: "Sample A",
                records: [KnowledgeRecord(id: "a.1", title: "Alpha topic", content: "Alpha content about widgets.", tags: ["widgets"])]
            ),
            sourceLabel: "test",
            enabled: true,
            in: repository
        )
        MindBootstrap.install(
            volume: KnowledgeVolume(
                id: "mind.sample-b",
                title: "Sample B",
                records: [KnowledgeRecord(id: "b.1", title: "Beta topic", content: "Beta content about gadgets.", tags: ["gadgets"])]
            ),
            sourceLabel: "test",
            enabled: true,
            in: repository
        )

        XCTAssertEqual(repository.listEnabledKnowledgeVolumes().count, 2)
    }
}
