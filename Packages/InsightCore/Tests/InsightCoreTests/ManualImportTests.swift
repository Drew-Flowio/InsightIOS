import XCTest
@testable import InsightCore
@testable import InsightStorage

final class PDFManualRecordBuilderTests: XCTestCase {
    func testBuildsPageRecordsWithReferences() {
        let records = PDFManualRecordBuilder.records(from: [
            (pageNumber: 1, text: "   "),
            (pageNumber: 2, text: "YAMAHA F150 Service Manual — inspect the telltale stream weekly."),
            (pageNumber: 3, text: "WARNING: HOT SURFACE. Allow engine to cool before servicing components."),
        ])

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].id, "page.2")
        XCTAssertEqual(records[0].title, "Page 2")
        XCTAssertEqual(records[0].tags, ["manual", "page:2"])
        XCTAssertEqual(records[1].title, "Page 3")
    }

    func testSkipsVeryShortPages() {
        let records = PDFManualRecordBuilder.records(from: [
            (pageNumber: 1, text: "Index"),
        ])

        XCTAssertTrue(records.isEmpty)
    }
}

final class ManualSourceAttributionTests: XCTestCase {
    func testRetrieverIncludesManualNameAndPageInSources() {
        let manual = KnowledgeVolume(
            id: "mind.manual.yamaha-f150.abcd",
            title: "Yamaha F150 Manual",
            summary: "Private manual",
            tags: ["manual", "private", "pdf"],
            records: [
                KnowledgeRecord(
                    id: "page.12",
                    title: "Page 12",
                    content: "A weak telltale stream often indicates restricted raw-water flow before overheating.",
                    tags: ["manual", "page:12"]
                ),
            ]
        )
        let official = KnowledgeVolume(
            id: "mind.florida-coastal-demo",
            title: "Florida Coastal",
            records: [
                KnowledgeRecord(
                    id: "outboard.telltale.weak-stream",
                    title: "Weak or intermittent telltale stream",
                    content: "Check the telltale outlet first when the stream is weak.",
                    tags: ["outboard", "telltale"]
                ),
            ]
        )

        let hits = KnowledgeRetriever().retrieve(
            query: "weak telltale stream on my outboard",
            volumes: [manual, official],
            maxResults: 4
        ).hits

        XCTAssertEqual(hits.count, 2)
        XCTAssertTrue(hits.contains { $0.volumeTitle == "Yamaha F150 Manual" && $0.recordTitle == "Page 12" })
        XCTAssertTrue(hits.contains { $0.volumeTitle == "Florida Coastal" })
        XCTAssertTrue(hits.first(where: { $0.recordID == "page.12" })?.excerpt.hasPrefix("p. 12 —") ?? false)
    }

    func testDuplicateManualVolumeIsRejected() throws {
        let repository = try Repository.inMemory()
        let manualsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("manual-dup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: manualsDirectory, withIntermediateDirectories: true)

        let pdfData = Data("placeholder".utf8)
        let volumeID = PDFManualParser.volumeID(for: "Service Manual.pdf", pdfData: pdfData)

        MindBootstrap.install(
            volume: KnowledgeVolume(
                id: volumeID,
                title: "Service Manual",
                records: [
                    KnowledgeRecord(
                        id: "page.1",
                        title: "Page 1",
                        content: "Inspect the telltale stream before each outing on coastal waters.",
                        tags: ["manual", "page:1"]
                    ),
                ]
            ),
            sourceLabel: "imported.pdf",
            enabled: true,
            in: repository
        )

        XCTAssertTrue(repository.knowledgeVolumeExists(id: volumeID))
    }
}
