import XCTest
@testable import InsightCore
@testable import InsightStorage

final class PhotoAttachmentPersistenceTests: XCTestCase {
    private var repository: Repository!

    override func setUpWithError() throws {
        repository = try Repository.inMemory()
    }

    func testPhotoQuestionPersistsImagePathAndOcrText() {
        var sessionManager = SessionManager(repository: repository, historyTurnsInPrompt: 4)

        let message = sessionManager.recordPhotoQuestion(
            question: "What does this warning mean?",
            imagePath: "/tmp/uploads/photo-abc.jpg",
            ocrText: "WARNING: HOT SURFACE\nMODEL 63P-12345"
        )

        let stored = repository.getSessionMessages(sessionID: message.sessionID).first

        XCTAssertEqual(stored?.source, "photo")
        XCTAssertEqual(stored?.content, "What does this warning mean?")
        XCTAssertEqual(stored?.imagePath, "/tmp/uploads/photo-abc.jpg")
        XCTAssertEqual(stored?.ocrText, "WARNING: HOT SURFACE\nMODEL 63P-12345")
    }
}

final class PhotoMindRetrievalTests: XCTestCase {
    func testOcrTextImprovesTelltaleRetrieval() throws {
        let volume = try BundledMinds.floridaCoastalDemoVolume()
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 800,
            height: 600,
            ocrText: "weak telltale stream outboard cooling",
            detectedLabels: ["outboard motor"]
        )

        let query = analysis.retrievalQuery(
            userQuestion: "What should I check on this engine?",
            editedOcr: nil
        )

        let result = KnowledgeRetriever().retrieve(query: query, volumes: [volume])

        XCTAssertEqual(result.hits.first?.recordID, "outboard.telltale.weak-stream")
    }
}
