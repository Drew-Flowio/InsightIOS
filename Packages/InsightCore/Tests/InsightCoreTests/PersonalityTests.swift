import XCTest
@testable import InsightCore
import InsightStorage

final class PersonalityCatalogTests: XCTestCase {
    func testBundledPresetsIncludeRequiredOptions() {
        let ids = Set(PersonalityCatalog.presets.map(\.id))
        XCTAssertTrue(ids.contains("offgrid_guide"))
        XCTAssertTrue(ids.contains("master_mechanic"))
        XCTAssertTrue(ids.contains("straight_shooter"))
        XCTAssertTrue(ids.contains("patient_teacher"))
        XCTAssertTrue(ids.contains("custom"))
    }

    func testPresetPromptsAreNonEmpty() {
        for preset in PersonalityCatalog.presets where preset.id != PersonalityCatalog.customPresetID {
            let prompt = PersonalityCatalog.prompt(for: preset.id)
            XCTAssertNotNil(prompt)
            XCTAssertFalse(prompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
    }

    func testCustomSelectionUsesSavedPrompt() {
        let custom = "You are Insight: terse and technical."
        let selection = PersonalityCatalog.resolveSelection(
            activePresetID: PersonalityCatalog.customPresetID,
            customPrompt: custom
        )

        XCTAssertEqual(selection.presetID, PersonalityCatalog.customPresetID)
        XCTAssertEqual(selection.name, "Custom")
        XCTAssertEqual(selection.promptText, custom)
    }

    func testResolveFallsBackToDefaultForUnknownPreset() {
        let selection = PersonalityCatalog.resolveSelection(
            activePresetID: "unknown_preset",
            customPrompt: nil
        )

        XCTAssertEqual(selection.presetID, PersonalityCatalog.defaultPresetID)
        XCTAssertEqual(selection.name, "Offgrid Guide")
    }
}

final class PersonalityPromptInjectionTests: XCTestCase {
    func testPromptBuilderInjectsActivePersonalitySeparatelyFromMemory() {
        let builder = PromptBuilder()
        let personality = "You are Insight in Straight Shooter mode."
        let memory = RelevantMemoryContext(userFacts: ["User owns a Honda generator."])

        let (messages, _) = builder.buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What should I check first?",
                imageDescription: nil,
                relevantMemory: memory,
                recentConversation: nil
            ),
            personalityPrompt: personality
        )

        XCTAssertTrue(messages[0].content.hasPrefix(personality))
        XCTAssertTrue(messages[0].content.contains("RELEVANT USER MEMORY:"))
        XCTAssertTrue(messages[0].content.contains("KNOWLEDGE VOLUME RECORDS:"))
        XCTAssertTrue(messages[0].content.contains("USER PROFILE:"))
        XCTAssertTrue(messages[0].content.contains("Straight Shooter mode."))
    }
}

final class PersonalityPersistenceTests: XCTestCase {
    func testRepositoryPersistsPersonalitySelectionAndCustomPrompt() throws {
        let repository = try Repository.inMemory()

        _ = repository.savePersonalitySettings(
            activePresetID: PersonalityCatalog.customPresetID,
            customPrompt: "Custom personality text."
        )

        let stored = repository.getPersonalitySettings()
        XCTAssertEqual(stored?.activePresetID, PersonalityCatalog.customPresetID)
        XCTAssertEqual(stored?.customPrompt, "Custom personality text.")
    }
}
