import XCTest
@testable import InsightCore
@testable import InsightEngine

final class PersonalMemoryEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testRememberCommandPersistsFactWithoutCallingKnowledgeSources() async throws {
        let engine = try makeEngine()

        let result = try await engine.sendTextMessage("Remember that I own a Honda EU2200i generator.")

        XCTAssertEqual(result.replyText, "Got it — I'll remember that.")
        XCTAssertTrue(result.knowledgeSources.isEmpty)
        XCTAssertTrue(result.assembledPromptDebug.hasPrefix("[MEMORY COMMAND]"))

        let facts = await engine.listMemoryFacts()
        XCTAssertEqual(facts.map(\.text), ["I own a Honda EU2200i generator."])
    }

    func testRecallCommandListsSavedMemories() async throws {
        let engine = try makeEngine()
        _ = await engine.addMemoryFact(text: "I keep spare oil in the garage.")
        _ = await engine.updateUserProfile(displayName: "Alex", responseStyle: "concise", generalNotes: nil)

        let result = try await engine.sendTextMessage("What do you remember about me?")

        XCTAssertTrue(result.replyText.contains("Alex"))
        XCTAssertTrue(result.replyText.contains("I keep spare oil in the garage."))
    }

    func testForgetCommandRemovesMatchingMemory() async throws {
        let engine = try makeEngine()
        _ = await engine.addMemoryFact(text: "I own a Honda EU2200i generator.")
        _ = await engine.addMemoryFact(text: "I live in Florida.")

        let result = try await engine.sendTextMessage("Forget that I own a Honda generator")

        XCTAssertEqual(result.replyText, "Okay, I've forgotten that.")
        let facts = await engine.listMemoryFacts().map(\.text)
        XCTAssertEqual(facts, ["I live in Florida."])
    }

    func testNormalQuestionDoesNotCreateMemoryFacts() async throws {
        let engine = try makeEngine()
        _ = try await engine.sendTextMessage("How do I winterize my generator?")

        let facts = await engine.listMemoryFacts()
        XCTAssertTrue(facts.isEmpty)
    }

    private func makeEngine() throws -> InsightEngine {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("memory.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            manualsDirectoryURL: tempDirectory.appendingPathComponent("manuals"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        return try InsightEngine(configuration: config)
    }
}
