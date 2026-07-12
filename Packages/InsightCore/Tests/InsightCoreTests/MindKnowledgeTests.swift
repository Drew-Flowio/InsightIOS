import XCTest
@testable import InsightCore

final class MindKnowledgeTests: XCTestCase {
    func testOGPackParserLoadsFloridaCoastalDemo() throws {
        let volume = try BundledMinds.floridaCoastalDemoVolume()

        XCTAssertEqual(volume.id, "mind.florida-coastal-demo")
        XCTAssertEqual(volume.title, "Florida Coastal")
        XCTAssertTrue(volume.records.contains { $0.id == "outboard.telltale.weak-stream" })
    }

    func testRetrieverFindsTelltaleRecordForWeakStreamQuestion() throws {
        let volume = try BundledMinds.floridaCoastalDemoVolume()
        let retriever = KnowledgeRetriever()

        let result = retriever.retrieve(
            query: "My outboard has a weak telltale stream. What should I check first?",
            volumes: [volume]
        )

        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.hits.first?.recordID, "outboard.telltale.weak-stream")
        XCTAssertEqual(result.hits.first?.volumeTitle, "Florida Coastal")
    }

    func testPromptBuilderInjectsRetrievedKnowledgeBlock() throws {
        let volume = try BundledMinds.floridaCoastalDemoVolume()
        let retriever = KnowledgeRetriever()
        let retrieved = retriever.retrieve(
            query: "weak telltale stream on my outboard",
            volumes: [volume]
        )

        let builder = PromptBuilder()
        let (messages, debugText) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What should I check?",
                imageDescription: nil,
                relevantMemory: RelevantMemoryContext(),
                retrievedKnowledge: retrieved,
                recentConversation: nil
            ),
            personalityPrompt: "You are a practical assistant."
        )

        XCTAssertTrue(messages[0].content.contains("KNOWLEDGE VOLUME RECORDS:"))
        XCTAssertTrue(messages[0].content.contains("Weak or intermittent telltale stream"))
        XCTAssertTrue(debugText.contains("KNOWLEDGE VOLUME RECORDS:"))
    }
}
