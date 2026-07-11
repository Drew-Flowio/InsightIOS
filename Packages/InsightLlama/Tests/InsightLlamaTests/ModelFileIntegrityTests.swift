import XCTest
@testable import InsightLlama

final class ModelFileIntegrityTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testAcceptableByteRangeUsesThreePercentTolerance() {
        let expected: Int64 = 1_000_000
        let range = ModelFileIntegrity.acceptableByteRange(for: expected)

        XCTAssertEqual(range.lowerBound, 970_000)
        XCTAssertEqual(range.upperBound, 1_030_000)
    }

    func testValidGGUFFilePassesIntegrityCheck() throws {
        let url = tempDirectory.appendingPathComponent("model.gguf")
        var data = Data("GGUF".utf8)
        data.append(Data(repeating: 0, count: 1_000_000 - 4))
        try data.write(to: url)

        XCTAssertTrue(ModelFileIntegrity.isValidModelFile(at: url, expectedBytes: 1_000_000))
    }

    func testWrongMagicFailsGGUFIntegrityCheck() throws {
        let url = tempDirectory.appendingPathComponent("model.gguf")
        let data = Data(repeating: 0, count: 1_000_000)
        try data.write(to: url)

        XCTAssertFalse(ModelFileIntegrity.isValidModelFile(at: url, expectedBytes: 1_000_000))
    }

    func testUndersizedFileFailsIntegrityCheck() throws {
        let url = tempDirectory.appendingPathComponent("model.gguf")
        var data = Data("GGUF".utf8)
        data.append(Data(repeating: 0, count: 100))
        try data.write(to: url)

        XCTAssertFalse(ModelFileIntegrity.isValidModelFile(at: url, expectedBytes: 1_000_000))
    }

    func testNonGGUFBinaryUsesSizeOnlyValidation() throws {
        let url = tempDirectory.appendingPathComponent("ggml-base.en.bin")
        let expected: Int64 = 10_000
        let data = Data(repeating: 0xAB, count: Int(expected))
        try data.write(to: url)

        XCTAssertTrue(ModelFileIntegrity.isValidModelFile(at: url, expectedBytes: expected))
    }
}
