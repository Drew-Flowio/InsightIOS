import XCTest
@testable import InsightCore

final class LocationContextTests: XCTestCase {
    func testPromptBlockIncludesCoordinatesWithoutPlaceName() {
        let snapshot = LocationSnapshot(
            latitude: 26.1223,
            longitude: -80.1372,
            horizontalAccuracyMeters: 12,
            headingDegrees: 180,
            speedMetersPerSecond: 0.4,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            quality: .good
        )
        let block = LocationContext(snapshot: snapshot).promptBlock()

        XCTAssertTrue(block.contains("LOCATION CONTEXT") == false)
        XCTAssertTrue(block.contains("26.1223") || block.contains("26.12230"))
        XCTAssertTrue(block.contains("Do not invent a city"))
        XCTAssertTrue(block.contains("geo:26.1,-80.1"))
    }

    func testPromptBuilderInjectsLocationContext() {
        let snapshot = LocationSnapshot(
            latitude: 25.7617,
            longitude: -80.1918,
            horizontalAccuracyMeters: 8,
            quality: .good
        )
        let (_, debugText) = PromptBuilder().buildAgentPrompt(
            AgentPromptInput(
                userQuestion: "What regulations apply here?",
                imageDescription: nil,
                locationDescription: LocationContext(snapshot: snapshot).promptBlock(),
                relevantMemory: RelevantMemoryContext(),
                recentConversation: nil
            ),
            personalityPrompt: "Test personality"
        )

        XCTAssertTrue(debugText.contains("LOCATION CONTEXT:"))
        XCTAssertTrue(debugText.contains("Coordinates:"))
    }

    func testRetrievalQueryIncludesGeographicTag() {
        let context = LocationContext(
            snapshot: LocationSnapshot(latitude: 26.1, longitude: -80.1, quality: .good)
        )
        let query = context.retrievalQuery(userQuestion: "anchor rules")
        XCTAssertTrue(query.contains("geo:26.1,-80.1"))
        XCTAssertTrue(query.contains("anchor rules"))
    }

    func testDeniedLocationHasUnavailableCaption() {
        let context = LocationContext(
            snapshot: LocationSnapshot(latitude: 0, longitude: 0, quality: .denied)
        )
        XCTAssertTrue(context.caption.contains("denied"))
    }

    func testSnapshotCodecRoundTrip() {
        let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = LocationSnapshot(
            latitude: 40.7128,
            longitude: -74.0060,
            horizontalAccuracyMeters: 15,
            capturedAt: capturedAt,
            quality: .good
        )
        let json = LocationSnapshotCodec.encode(snapshot)
        XCTAssertNotNil(json)
        let decoded = LocationSnapshotCodec.decode(json!)
        XCTAssertEqual(decoded, snapshot)
    }
}
