import XCTest
@testable import InsightCore
@testable import InsightStorage

final class LocationPersistenceTests: XCTestCase {
    private var repository: Repository!

    override func setUpWithError() throws {
        repository = try Repository.inMemory()
    }

    func testUserMessagePersistsLocationJSON() throws {
        let session = repository.createSession()
        let snapshot = LocationSnapshot(
            latitude: 26.1223,
            longitude: -80.1372,
            horizontalAccuracyMeters: 10,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            quality: .good
        )
        let json = LocationSnapshotCodec.encode(snapshot)
        XCTAssertNotNil(json)

        _ = repository.addMessage(
            sessionID: session.id,
            role: "user",
            content: "What are the local speed rules?",
            source: "text",
            locationJSON: json
        )

        let messages = repository.getSessionMessages(sessionID: session.id)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].locationJSON, json)
        XCTAssertEqual(LocationSnapshotCodec.decode(messages[0].locationJSON!), snapshot)
    }
}
