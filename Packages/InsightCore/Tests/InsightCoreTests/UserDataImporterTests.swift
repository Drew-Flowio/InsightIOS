import XCTest
@testable import InsightCore

final class UserDataImporterTests: XCTestCase {
    func testCSVImportBuildsRecordsWithGeographicTags() throws {
        let csv = """
        title,description,latitude,longitude,tags
        Dock Box,Spare impeller and flare kit,26.1001,-80.1202,safety
        """.utf8
        let volume = try UserDataImporter.buildVolume(
            data: Data(csv),
            filename: "inventory.csv",
            title: "Boat Inventory",
            kind: .csv
        )

        XCTAssertEqual(volume.records.count, 1)
        XCTAssertEqual(volume.records[0].title, "Dock Box")
        XCTAssertTrue(volume.records[0].tags.contains("geo:26.1001,-80.1202"))
        XCTAssertTrue(volume.records[0].tags.contains("geo-name:Dock Box"))
    }

    func testJSONImportDetectsLatitudeAndLongitudeFields() throws {
        let json = """
        [
          {
            "name": "Trailhead cache",
            "notes": "Water filter and first-aid kit.",
            "lat": 26.05,
            "lon": -80.15
          }
        ]
        """.utf8
        let volume = try UserDataImporter.buildVolume(
            data: Data(json),
            filename: "cache.json",
            title: "Trail Cache",
            kind: .json
        )

        XCTAssertEqual(volume.records.count, 1)
        XCTAssertTrue(volume.records[0].tags.contains { $0.hasPrefix("geo:26.0500,") })
    }

    func testTextImportCreatesSingleRecordFromPlainFile() throws {
        let text = "Generator oil change every 50 hours.\nUse 10W-30 when ambient temps are moderate.".utf8
        let volume = try UserDataImporter.buildVolume(
            data: Data(text),
            filename: "maintenance.txt",
            title: "Maintenance Notes",
            kind: .text
        )

        XCTAssertEqual(volume.records.count, 1)
        XCTAssertEqual(volume.records[0].title, "Maintenance Notes")
        XCTAssertTrue(volume.records[0].content.contains("Generator oil change"))
    }

    func testPreviewReportsRecordCountAndGeographicRecords() throws {
        let csv = """
        title,description,latitude,longitude
        Marina Gate,Call ahead after 6pm,26.2,-80.1
        Shop Note,Keep fuel stabilizer onboard,,
        """.utf8

        let preview = try UserDataImporter.preview(data: Data(csv), filename: "places.csv")
        XCTAssertEqual(preview.fileKind, .csv)
        XCTAssertEqual(preview.recordCount, 2)
        XCTAssertEqual(preview.geographicRecordCount, 1)
        XCTAssertEqual(preview.suggestedTitle, "places")
    }
}
