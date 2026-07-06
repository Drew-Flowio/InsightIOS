import XCTest
@testable import InsightCore

final class InsightCoreTests: XCTestCase {
    func testBuildAgentPromptSeparatesImageMemoryAndQuestion() {
        let builder = PromptBuilder()
        let memory = RelevantMemoryContext(
            userPreferences: ["User prefers concise answers."],
            userFacts: ["User owns a Honda generator."],
            pastConversationContext: ["User was troubleshooting a no-start issue."]
        )

        let (messages, debugText) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What is wrong with this plug?",
                imageDescription: "Main visible objects/categories detected: electrical plug. Text visible in the image: No readable text detected. Uncertainty: Medium confidence.",
                relevantMemory: memory,
                recentConversation: "User: The generator will not start."
            )
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
        XCTAssertTrue(messages[0].content.contains("IMAGE CONTEXT:"))
        XCTAssertTrue(messages[0].content.contains("RELEVANT USER MEMORY:"))
        XCTAssertTrue(messages[0].content.contains("User preferences:"))
        XCTAssertTrue(messages[0].content.contains("Do not invent details"))
        XCTAssertTrue(messages[1].content.contains("USER QUESTION:"))
        XCTAssertTrue(debugText.contains("[SYSTEM]"))
    }

    func testValidateAgentResponseRejectsGenericImageContext() {
        let builder = PromptBuilder()
        let validation = builder.validateAgentResponse(
            "It is definitely safe to use.",
            imageDescription: "A photo.",
            userQuestion: "Is this safe from the photo?"
        )

        XCTAssertFalse(validation.shouldRegenerate)
        XCTAssertTrue(validation.text.contains("can’t read enough"))
        XCTAssertEqual(validation.reason, "Image description was empty or generic.")
    }

    func testSpeechTextTruncatesAtHandoffAndStripsMarkdown() {
        let input = """
        **Hold up** — kill the breaker first.

        I'll put the longer details in text for you.

        - step one
        - step two
        """

        let spoken = SpeechText.prepareForSpeech(input)
        XCTAssertEqual(
            spoken,
            "Hold up — kill the breaker first. I'll put the longer details in text for you."
        )
    }

    func testBundledSystemPromptLoads() {
        let prompt = DefaultPrompts.bundledSystemPrompt()
        XCTAssertTrue(prompt.contains("You are Insight"))
        XCTAssertTrue(prompt.contains("Safety:"))
    }
}
