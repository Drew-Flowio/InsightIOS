import XCTest
@testable import InsightCore

final class GeographicRecordTests: XCTestCase {
    func testParserReadsPlaceRecordWithAttribution() {
        let volume = KnowledgeVolume(
            id: "mind.demo",
            title: "Coastal Demo",
            records: [
                KnowledgeRecord(
                    id: "place.inlet",
                    title: "Fallback title",
                    content: "Commercial inlet with strong tidal flow.",
                    tags: [
                        "geo:26.0889,-80.1167",
                        "geo-type:place",
                        "geo-name:Port Everglades Inlet",
                        "coastal"
                    ]
                )
            ]
        )

        let record = GeographicRecordParser.records(from: volume).first
        XCTAssertEqual(record?.name, "Port Everglades Inlet")
        XCTAssertEqual(record?.kind, .place)
        XCTAssertEqual(record?.volumeTitle, "Coastal Demo")
        XCTAssertEqual(record?.sourceAttribution, "Coastal Demo")
        XCTAssertEqual(record?.description, "Commercial inlet with strong tidal flow.")
    }

    func testParserReadsZoneRadius() {
        let record = GeographicRecordParser.parse(
            record: KnowledgeRecord(
                id: "zone.no-wake",
                title: "No-wake zone",
                content: "Reduced speed near marina.",
                tags: ["geo:26.1000,-80.1200", "geo-type:zone", "geo-radius:800"]
            ),
            volumeID: "mind.demo",
            volumeTitle: "Harbor Rules",
            sourceLabel: "bundled.ogpack"
        )

        XCTAssertEqual(record?.kind, .zone)
        XCTAssertEqual(record?.radiusMeters, 800)
        XCTAssertEqual(record?.sourceAttribution, "Harbor Rules · bundled.ogpack")
    }

    func testNearbyMatcherSelectsClosestRecords() {
        let records = [
            GeographicRecord(
                recordID: "far",
                volumeID: "mind.demo",
                volumeTitle: "Demo",
                kind: .place,
                name: "Far Point",
                description: "Far",
                latitude: 27.0,
                longitude: -81.0
            ),
            GeographicRecord(
                recordID: "near",
                volumeID: "mind.demo",
                volumeTitle: "Demo",
                kind: .place,
                name: "Near Point",
                description: "Near",
                latitude: 26.09,
                longitude: -80.12
            )
        ]

        let nearby = NearbyGeographicMatcher.nearbyRecords(
            from: records,
            latitude: 26.0889,
            longitude: -80.1167,
            searchRadiusMeters: 20_000,
            maxResults: 2
        )

        XCTAssertEqual(nearby.count, 1)
        XCTAssertEqual(nearby.first?.record.name, "Near Point")
        XCTAssertLessThan(nearby.first?.distanceMeters ?? .infinity, 5_000)
    }

    func testNearestNamedPlaceRequiresInstalledSourceName() {
        let nearby = [
            NearbyGeographicRecord(
                record: GeographicRecord(
                    recordID: "place.inlet",
                    volumeID: "mind.demo",
                    volumeTitle: "Florida Coastal",
                    sourceLabel: "bundled.ogpack",
                    kind: .place,
                    name: "Port Everglades Inlet",
                    description: "Inlet notes",
                    latitude: 26.0889,
                    longitude: -80.1167
                ),
                distanceMeters: 900
            )
        ]

        let nearest = NearbyGeographicMatcher.nearestNamedPlace(in: nearby)
        XCTAssertEqual(nearest?.record.name, "Port Everglades Inlet")
        XCTAssertEqual(nearest?.record.sourceAttribution, "Florida Coastal · bundled.ogpack")
    }
}
