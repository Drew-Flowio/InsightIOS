import XCTest
@testable import InsightCore
@testable import InsightEngine
@testable import InsightStorage

final class MindLibraryTests: XCTestCase {
    func testEngineListsMindLibraryItemsAfterBootstrap() async throws {
        let engine = try makeEngine()

        let items = await engine.listMindLibraryItems()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "mind.florida-coastal-demo")
        XCTAssertEqual(items.first?.version, "1.1")
        XCTAssertEqual(items.first?.recordCount, 6)
    }

    func testEngineImportAndDuplicateHandling() async throws {
        let engine = try makeEngine()
        let data = try BundledMinds.floridaCoastalDemoData()

        let duplicate = await engine.importMind(from: data)
        XCTAssertEqual(duplicate, .duplicate(title: "Florida Coastal"))

        let custom = try sampleOGPackData(id: "mind.custom-import", title: "Custom Import")
        let imported = await engine.importMind(from: custom)
        XCTAssertEqual(imported, .imported(title: "Custom Import"))

        let items = await engine.listMindLibraryItems()
        XCTAssertEqual(items.count, 2)
    }

    func testEngineEnableDisableMind() async throws {
        let engine = try makeEngine()

        await engine.setMindEnabled(mindID: "mind.florida-coastal-demo", enabled: false)
        let disabled = await engine.listEnabledMinds()
        XCTAssertEqual(disabled.count, 0)

        await engine.setMindEnabled(mindID: "mind.florida-coastal-demo", enabled: true)
        let enabled = await engine.listEnabledMinds()
        XCTAssertEqual(enabled.count, 1)
    }

    private func makeEngine() throws -> InsightEngine {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("insight-mind-library-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let config = AppConfiguration(
            mockMode: true,
            databaseURL: base.appendingPathComponent("test.db"),
            uploadsDirectoryURL: base.appendingPathComponent("uploads"),
            manualsDirectoryURL: base.appendingPathComponent("manuals"),
            modelsDirectoryURL: base.appendingPathComponent("models")
        )
        return try InsightEngine(configuration: config)
    }

    private func sampleOGPackData(id: String, title: String) throws -> Data {
        let document = OGPackDocument(
            formatVersion: 1,
            volume: OGPackVolume(
                id: id,
                title: title,
                version: "2.1",
                summary: "Imported test mind."
            ),
            records: [
                OGPackRecord(
                    id: "record.one",
                    title: "Sample record",
                    content: "Sample knowledge content about widgets and gadgets.",
                    tags: ["widgets"]
                ),
            ]
        )
        return try JSONEncoder().encode(document)
    }
}
