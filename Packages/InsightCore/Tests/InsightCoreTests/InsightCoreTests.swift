import XCTest
@testable import InsightCore

final class InsightCoreTests: XCTestCase {
    func testPromptBuilderIncludesMemoryFactsAndVisualContext() {
        let builder = PromptBuilder()
        let visual = VisualContext(imagePath: "/tmp/photo.jpg", caption: "A frayed power cable.")

        let (messages, debugText) = builder.build(
            personalityPrompt: "You are Insight.",
            memoryFacts: ["User prefers metric units."],
            historyMessages: [ChatMessage(role: "user", content: "Hey")],
            historySummaryNote: "(2 earlier message(s) in this session are not shown verbatim.)",
            currentUtterance: "Is this safe?",
            visualContext: visual
        )

        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertTrue(messages[0].content.contains("long-term memory"))
        XCTAssertTrue(messages[0].content.contains("frayed power cable"))
        XCTAssertTrue(messages[0].content.contains("earlier message"))
        XCTAssertEqual(messages.last?.content, "Is this safe?")
        XCTAssertTrue(debugText.contains("[SYSTEM]"))
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
