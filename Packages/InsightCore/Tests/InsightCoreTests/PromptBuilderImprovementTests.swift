import XCTest
@testable import InsightCore

final class PromptBuilderImprovementTests: XCTestCase {
    private let builder = PromptBuilder()

    func testSendRouterRoutesToImprovementWhenBuilderEnabled() {
        let decision = PromptBuilderSendRouter.decision(text: "  telltale weak  ", builderEnabled: true)
        XCTAssertEqual(decision, .improveQuestion(roughText: "telltale weak"))
    }

    func testSendRouterRoutesToNormalSendWhenBuilderDisabled() {
        let decision = PromptBuilderSendRouter.decision(text: "What should I check?", builderEnabled: false)
        XCTAssertEqual(decision, .sendNormally(text: "What should I check?"))
    }

    func testSendRouterIgnoresEmptyText() {
        XCTAssertNil(PromptBuilderSendRouter.decision(text: "   ", builderEnabled: true))
    }

    func testApplyDraftTurnsBuilderOffWithoutAutoSend() {
        var builderEnabled = true
        let draft = PromptBuilderSendRouter.applyDraft(
            improved: "My outboard telltale stream is weak after warmup. What should I check first, and cite the manual?",
            original: "telltale weak",
            builderEnabled: &builderEnabled
        )

        XCTAssertFalse(builderEnabled)
        XCTAssertEqual(draft.originalText, "telltale weak")
        XCTAssertTrue(draft.improvedText.contains("telltale"))
        XCTAssertNotEqual(draft.improvedText, draft.originalText)
    }

    func testBuildPromptImprovementMessagesIncludesRoughQuestionAndContext() {
        let messages = builder.buildPromptImprovementMessages(
            PromptImprovementInput(
                roughQuestion: "telltale weak",
                imageDescription: "Photo shows outboard cowling.",
                workspaceDescription: "User is viewing a photo in the workspace.",
                locationDescription: "Approximate GPS near coastal marina.",
                enabledMindTitles: ["Florida Coastal Demo"],
                userProfile: UserProfileContext(displayName: "Alex"),
                relevantMemory: RelevantMemoryContext(userFacts: ["Owns Yamaha F150"]),
                retrievedKnowledge: RetrievedKnowledgeContext(
                    hits: [
                        KnowledgeSourceAttribution(
                            volumeID: "mind.demo",
                            volumeTitle: "Florida Coastal Demo",
                            recordID: "outboard.telltale",
                            recordTitle: "Weak telltale",
                            excerpt: "Check the telltale outlet first."
                        )
                    ]
                )
            )
        )

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].role, "system")
        XCTAssertTrue(messages[0].content.contains("Do NOT answer the question"))
        XCTAssertTrue(messages[1].content.contains("ROUGH QUESTION:"))
        XCTAssertTrue(messages[1].content.contains("telltale weak"))
        XCTAssertTrue(messages[1].content.contains("Florida Coastal Demo"))
        XCTAssertTrue(messages[1].content.contains("Check the telltale outlet first."))
    }

    func testSanitizeImprovedPromptStripsLabelsAndQuotes() {
        let cleaned = builder.sanitizeImprovedPrompt("""
        Improved question: "My outboard telltale stream is weak. What should I check first?"
        """)
        XCTAssertFalse(cleaned.lowercased().hasPrefix("improved"))
        XCTAssertFalse(cleaned.hasPrefix("\""))
        XCTAssertTrue(cleaned.contains("telltale"))
    }
}
