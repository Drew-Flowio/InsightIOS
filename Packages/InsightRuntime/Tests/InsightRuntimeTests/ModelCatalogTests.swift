import XCTest
@testable import InsightRuntime

final class ModelCatalogTests: XCTestCase {
    func testPrimaryUsesPhi35WithPermissiveLicense() {
        XCTAssertEqual(ModelCatalog.primaryHighQuality.license, "MIT")
        XCTAssertTrue(ModelCatalog.primaryHighQuality.llmFileName.contains("Phi-3.5"))
        XCTAssertTrue(ModelCatalog.primaryHighQuality.llmFileName.contains("Q4_K_M"))
    }

    func testCompactUsesApacheLicensedQwen15B() {
        XCTAssertEqual(ModelCatalog.compact.license, "Apache-2.0")
        XCTAssertTrue(ModelCatalog.compact.llmFileName.contains("1.5B"))
    }
}
