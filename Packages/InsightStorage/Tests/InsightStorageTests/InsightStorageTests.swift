import XCTest
@testable import InsightStorage

final class InsightStorageTests: XCTestCase {
    func testRepositoryPersistsSessionMessagesAndMemoryFacts() throws {
        let repository = try Repository.inMemory()
        let session = repository.createSession()

        _ = repository.addMessage(sessionID: session.id, role: "user", content: "Hello")
        _ = repository.addMessage(
            sessionID: session.id,
            role: "assistant",
            content: "Hey there.",
            promptVersionID: nil,
            latencyMs: 42
        )
        _ = repository.addMemoryFact(text: "Likes concise answers.")

        XCTAssertEqual(repository.countSessionMessages(sessionID: session.id), 2)
        XCTAssertEqual(repository.listMemoryFacts().map(\.text), ["Likes concise answers."])

        let prompt = repository.savePromptVersion(content: "You are Insight.", label: "Default")
        XCTAssertEqual(repository.getActivePromptVersion()?.id, prompt.id)

        repository.endSession(sessionID: session.id)
        XCTAssertNil(repository.getLatestActiveSession())
    }
}
