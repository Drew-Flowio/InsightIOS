import XCTest
@testable import InsightCore
@testable import InsightStorage

final class MindImporterTests: XCTestCase {
    private var repository: Repository!

    override func setUpWithError() throws {
        repository = try Repository.inMemory()
    }

    func testImportInstallsVolumeFromOGPack() throws {
        let data = try BundledMinds.floridaCoastalDemoData()

        let outcome = MindImporter.importOGPack(data: data, into: repository)

        XCTAssertEqual(outcome, .imported(title: "Florida Coastal"))
        XCTAssertTrue(repository.knowledgeVolumeExists(id: "mind.florida-coastal-demo"))
        XCTAssertEqual(repository.countKnowledgeRecords(volumeID: "mind.florida-coastal-demo"), 3)
    }

    func testImportRejectsDuplicateVolumeID() throws {
        let data = try BundledMinds.floridaCoastalDemoData()

        _ = MindImporter.importOGPack(data: data, into: repository)
        let second = MindImporter.importOGPack(data: data, into: repository)

        XCTAssertEqual(second, .duplicate(title: "Florida Coastal"))
        XCTAssertEqual(repository.listKnowledgeVolumes().count, 1)
    }

    func testImportRejectsInvalidPayload() {
        let outcome = MindImporter.importOGPack(data: Data("{}".utf8), into: repository)

        guard case .failed = outcome else {
            return XCTFail("Expected failed outcome.")
        }
        XCTAssertFalse(repository.knowledgeVolumeExists(id: "mind.florida-coastal-demo"))
    }
}

final class MindEnablePersistenceTests: XCTestCase {
    private var repository: Repository!

    override func setUpWithError() throws {
        repository = try Repository.inMemory()
        MindBootstrap.seedBundledMindsIfNeeded(in: repository)
    }

    func testDisableMindPersistsAcrossReads() {
        repository.setKnowledgeVolumeEnabled(id: "mind.florida-coastal-demo", enabled: false)

        XCTAssertEqual(repository.listEnabledKnowledgeVolumes().count, 0)
        XCTAssertFalse(repository.listKnowledgeVolumes().first?.isEnabled ?? true)

        repository.setKnowledgeVolumeEnabled(id: "mind.florida-coastal-demo", enabled: true)

        XCTAssertEqual(repository.listEnabledKnowledgeVolumes().count, 1)
        XCTAssertTrue(repository.listKnowledgeVolumes().first?.isEnabled ?? false)
    }
}
