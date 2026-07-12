import XCTest
@testable import InsightLlama
import InsightRuntime

final class ModelFileStoreVisionTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testVisionReadyRequiresBothValidatedFiles() throws {
        let bundle = ModelCatalog.primaryHighQuality
        let store = ModelFileStore(modelsDirectory: tempDirectory, bundle: bundle)

        XCTAssertFalse(store.isVisionReady)

        try writeValidGGUF(
            at: store.visionModelURL,
            expectedBytes: bundle.visionModelDiskBytes
        )
        XCTAssertFalse(store.isVisionReady)

        try writeValidGGUF(
            at: store.visionMmprojURL,
            expectedBytes: bundle.visionMmprojDiskBytes
        )
        XCTAssertTrue(store.isVisionReady)
    }

    func testRemoveVisionModelsDeletesOnlyVisionAssets() throws {
        let bundle = ModelCatalog.primaryHighQuality
        let store = ModelFileStore(modelsDirectory: tempDirectory, bundle: bundle)

        try writeValidGGUF(at: store.visionModelURL, expectedBytes: bundle.visionModelDiskBytes)
        try writeValidGGUF(at: store.visionMmprojURL, expectedBytes: bundle.visionMmprojDiskBytes)
        try Data(repeating: 0xAB, count: 64).write(to: store.llmModelURL)

        try ModelDownloadService.removeVisionModels(bundle: bundle, from: tempDirectory)

        XCTAssertFalse(store.isVisionReady)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.llmModelURL.path))
    }

    private func writeValidGGUF(at url: URL, expectedBytes: Int64) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        var data = Data("GGUF".utf8)
        data.append(Data(repeating: 0, count: Int(expectedBytes) - 4))
        try data.write(to: url)
    }
}
