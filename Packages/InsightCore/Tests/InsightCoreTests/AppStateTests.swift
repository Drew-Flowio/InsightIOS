import XCTest
@testable import InsightCore

final class AppStateTests: XCTestCase {
    func testStreamingStateIsDistinctFromThinking() {
        XCTAssertTrue(AppState.allCases.contains(.streaming))
        XCTAssertNotEqual(AppState.thinking, AppState.streaming)
    }
}
