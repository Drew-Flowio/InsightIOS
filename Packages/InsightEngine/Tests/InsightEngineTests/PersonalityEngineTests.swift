import XCTest
@testable import InsightCore
@testable import InsightEngine

final class PersonalityEngineTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testSelectPersonalityPersistsAndUpdatesActivePrompt() async throws {
        let engine = try makeEngine()

        let selection = await engine.selectPersonality(presetID: "master_mechanic")

        XCTAssertEqual(selection.presetID, "master_mechanic")
        XCTAssertEqual(selection.name, "Master Mechanic")
        XCTAssertTrue(selection.promptText.contains("Master Mechanic mode"))

        let active = await engine.getActivePersonality()
        XCTAssertEqual(active.presetID, "master_mechanic")
        let storedPrompt = await engine.getSystemPrompt()
        XCTAssertEqual(storedPrompt, active.promptText)
    }

    func testCustomPersonalityPromptIsEditableAndPersisted() async throws {
        let engine = try makeEngine()
        let custom = "You are Insight: calm, curious, and precise."

        let selection = await engine.updateCustomPersonalityPrompt(custom)

        XCTAssertEqual(selection.presetID, PersonalityCatalog.customPresetID)
        XCTAssertEqual(selection.promptText, custom)
        let storedPrompt = await engine.getSystemPrompt()
        XCTAssertEqual(storedPrompt, custom)
    }

    func testRestoreDefaultPersonalityResetsToOffgridGuide() async throws {
        let engine = try makeEngine()
        _ = await engine.selectPersonality(presetID: "straight_shooter")

        let restored = await engine.restoreDefaultPersonality()

        XCTAssertEqual(restored.presetID, PersonalityCatalog.defaultPresetID)
        XCTAssertEqual(restored.name, "Offgrid Guide")
        XCTAssertTrue(restored.promptText.contains("You are Insight"))
    }

    private func makeEngine() throws -> InsightEngine {
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: tempDirectory.appendingPathComponent("personality.db"),
            uploadsDirectoryURL: tempDirectory.appendingPathComponent("uploads"),
            manualsDirectoryURL: tempDirectory.appendingPathComponent("manuals"),
            modelsDirectoryURL: tempDirectory.appendingPathComponent("models")
        )
        return try InsightEngine(configuration: config)
    }
}
