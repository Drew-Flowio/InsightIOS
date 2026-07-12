import XCTest
@testable import InsightCore
import InsightStorage

final class MemoryCommandParserTests: XCTestCase {
    private let parser = MemoryCommandParser()

    func testParsesRememberThatCommand() {
        XCTAssertEqual(parser.parse("Remember that I own a Honda EU2200i."), .remember(fact: "I own a Honda EU2200i."))
        XCTAssertEqual(parser.parse("please remember: my boat is docked in Key West"), .remember(fact: "my boat is docked in Key West"))
    }

    func testParsesRecallCommand() {
        XCTAssertEqual(parser.parse("What do you remember about me?"), .recall(query: nil))
        XCTAssertEqual(parser.parse("What do you remember about my generator?"), .recall(query: "my generator"))
    }

    func testParsesForgetCommand() {
        XCTAssertEqual(parser.parse("Forget that I own a Honda"), .forget(target: "that I own a Honda"))
        XCTAssertEqual(parser.parse("Forget everything"), .forget(target: "everything"))
    }

    func testIgnoresNormalQuestions() {
        XCTAssertEqual(parser.parse("How do I winterize my generator?"), .none)
    }
}

final class PersonalMemoryRetrieverTests: XCTestCase {
    private let retriever = PersonalMemoryRetriever()

    func testRetrieveMatchesKeywords() {
        let facts = [
            "User owns a Honda EU2200i generator.",
            "User prefers concise answers.",
            "User lives in Florida.",
        ]

        let context = retriever.retrieve(facts: facts, for: "Tell me about my Honda generator")
        XCTAssertTrue(context.userFacts.contains("User owns a Honda EU2200i generator."))
        XCTAssertFalse(context.userFacts.contains("User lives in Florida."))
    }

    func testRejectInvalidMemoryFacts() {
        XCTAssertFalse(retriever.isValidMemoryFact("ab"))
        XCTAssertFalse(retriever.isValidMemoryFact("Retrieved from knowledge volume page: 12"))
        XCTAssertTrue(retriever.isValidMemoryFact("I keep spare fuel stabilizer in the garage."))
    }

    func testForgetMatchingUsesKeywords() {
        let facts = [
            "User owns a Honda EU2200i generator.",
            "User lives in Florida.",
        ]
        let matches = retriever.matchingFactTexts(facts: facts, target: "Honda generator")
        XCTAssertEqual(matches, ["User owns a Honda EU2200i generator."])
    }
}

final class PersonalMemoryPromptTests: XCTestCase {
    func testPromptBuilderSeparatesProfileMemoryAndKnowledge() {
        let builder = PromptBuilder()
        let profile = UserProfileContext(displayName: "Alex", responseStyle: "concise", generalNotes: "Weekend sailor.")
        let memory = RelevantMemoryContext(userFacts: ["User owns a Honda generator."])
        let knowledge = RetrievedKnowledgeContext(hits: [
            KnowledgeSourceAttribution(
                volumeID: "mind.demo",
                volumeTitle: "Florida Coastal",
                recordID: "rec.1",
                recordTitle: "Storm prep",
                excerpt: "Secure dock lines early."
            ),
        ])

        let (messages, _) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What should I do before a storm?",
                imageDescription: nil,
                userProfile: profile,
                relevantMemory: memory,
                retrievedKnowledge: knowledge,
                recentConversation: nil
            ),
            personalityPrompt: "You are Insight."
        )

        XCTAssertTrue(messages[0].content.contains("USER PROFILE:"))
        XCTAssertTrue(messages[0].content.contains("RELEVANT USER MEMORY:"))
        XCTAssertTrue(messages[0].content.contains("KNOWLEDGE VOLUME RECORDS:"))
        XCTAssertTrue(messages[0].content.contains("Alex"))
        XCTAssertTrue(messages[0].content.contains("User owns a Honda generator."))
        XCTAssertTrue(messages[0].content.contains("Storm prep"))
        XCTAssertTrue(messages[0].content.contains("Secure dock lines early."))
    }
}

final class PersonalMemorySeparationTests: XCTestCase {
    func testKnowledgeSourcesAreNotSavedAsMemoryFacts() throws {
        let repository = try Repository.inMemory()
        let retriever = PersonalMemoryRetriever()
        let knowledgeExcerpt = "Florida Coastal manual page: 12 — Secure dock lines early."

        XCTAssertFalse(retriever.isValidMemoryFact(knowledgeExcerpt))
        _ = repository.addMemoryFact(text: "User owns a dock in Key West.")
        XCTAssertEqual(repository.listMemoryFacts().count, 1)
    }
}
