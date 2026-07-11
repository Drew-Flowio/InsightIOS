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
                imageDescription: "Main visible objects/categories detected: electrical plug.",
                relevantMemory: memory,
                recentConversation: "User: The generator will not start."
            ),
            personalityPrompt: DefaultPrompts.bundledSystemPrompt()
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertEqual(messages[1].role, "user")
        XCTAssertTrue(messages[0].content.contains("You are Insight"))
        XCTAssertTrue(messages[0].content.contains("IMAGE CONTEXT:"))
        XCTAssertTrue(messages[0].content.contains("RELEVANT USER MEMORY:"))
        XCTAssertTrue(messages[1].content.contains("USER QUESTION:"))
        XCTAssertTrue(debugText.contains("[SYSTEM]"))
    }

    func testActivePersonalityPromptIsInjectedIntoSystemMessage() {
        let builder = PromptBuilder()
        let customPersonality = "You are Offgrid Minds: calm, practical, and direct."

        let (messages, _) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "Is this safe?",
                imageDescription: nil,
                relevantMemory: RelevantMemoryContext(),
                recentConversation: nil
            ),
            personalityPrompt: customPersonality
        )

        XCTAssertTrue(messages[0].content.hasPrefix(customPersonality))
        XCTAssertFalse(messages[0].content.contains("reasoning agent for Offgrid Minds"))
    }

    func testSanitizeStreamingTokenRemovesSpecialTokens() {
        let builder = PromptBuilder()

        XCTAssertEqual(builder.sanitizeStreamingToken("Hello<|end|>"), "Hello")
        XCTAssertEqual(builder.sanitizeStreamingToken("<|assistant|>Sure"), "Sure")
        XCTAssertEqual(builder.sanitizeModelOutput("Done<|endoftext|> "), "Done")
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
