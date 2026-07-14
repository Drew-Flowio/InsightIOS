import XCTest
@testable import InsightCore

final class VisualWorkspaceSupportTests: XCTestCase {
    func testParsesManualPageNumberFromRecordID() {
        XCTAssertEqual(ManualPageReference.pageNumber(fromRecordID: "page.12"), 12)
        XCTAssertNil(ManualPageReference.pageNumber(fromRecordID: "outboard.telltale"))
    }

    func testDetectsManualVolumeIDs() {
        XCTAssertTrue(ManualPageReference.isManualVolumeID("mind.manual.my-boat.ab12cd34"))
        XCTAssertFalse(ManualPageReference.isManualVolumeID("mind.florida-coastal-demo"))
    }
}
