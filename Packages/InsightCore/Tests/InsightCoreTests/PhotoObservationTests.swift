import XCTest
@testable import InsightCore

final class PhotoObservationTests: XCTestCase {
    func testPromptBlockStatesModelCannotSeeImageDirectly() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 1024,
            height: 768,
            ocrText: "YAMAHA F150\nWARNING: HOT SURFACE",
            detectedLabels: ["outboard motor"]
        )

        let block = analysis.promptBlock(editedOcr: nil)

        XCTAssertTrue(block.contains("cannot see the image directly"))
        XCTAssertTrue(block.contains("Extracted text (OCR):"))
        XCTAssertTrue(block.contains("YAMAHA F150"))
        XCTAssertTrue(block.contains("outboard motor"))
    }

    func testEditedOcrOverridesDetectedTextInPrompt() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 800,
            height: 600,
            ocrText: "OLD TEXT",
            detectedLabels: []
        )

        let block = analysis.promptBlock(editedOcr: "Corrected model 63P-12345")

        XCTAssertTrue(block.contains("Corrected model 63P-12345"))
        XCTAssertFalse(block.contains("OLD TEXT"))
    }

    func testRetrievalQueryCombinesQuestionAndOcr() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 800,
            height: 600,
            ocrText: "weak telltale stream",
            detectedLabels: ["outboard"]
        )

        let query = analysis.retrievalQuery(
            userQuestion: "What should I check?",
            editedOcr: nil
        )

        XCTAssertTrue(query.contains("weak telltale stream"))
        XCTAssertTrue(query.contains("What should I check?"))
        XCTAssertTrue(query.contains("outboard"))
    }

    func testPromptBuilderInjectsPhotoObservations() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 640,
            height: 480,
            ocrText: "MODEL ABC-123",
            detectedLabels: ["equipment label"]
        )
        let context = VisualContext(analysis: analysis)
        let builder = PromptBuilder()

        let (messages, debugText) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What does this label mean?",
                imageDescription: context.promptBlock(),
                relevantMemory: RelevantMemoryContext(),
                retrievedKnowledge: RetrievedKnowledgeContext(),
                recentConversation: nil
            ),
            personalityPrompt: "You are a practical assistant."
        )

        XCTAssertTrue(messages[0].content.contains("cannot see the image directly"))
        XCTAssertTrue(messages[0].content.contains("MODEL ABC-123"))
        XCTAssertTrue(debugText.contains("IMAGE CONTEXT:"))
    }
}
