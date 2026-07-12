import XCTest
@testable import InsightCore

final class VisualObservationsParserTests: XCTestCase {
    private let parser = VisualObservationsParser()

    func testParsesStructuredJSON() {
        let raw = """
        {"visibleObjects":["gauge","hose"],"readableLabels":["120 PSI"],"possibleProblems":["frayed hose"],"confidence":"medium","needsAnotherAngle":true,"summary":"Pressure gauge with worn hose."}
        """

        let observations = parser.parse(raw)

        XCTAssertEqual(observations?.visibleObjects, ["gauge", "hose"])
        XCTAssertEqual(observations?.confidence, .medium)
        XCTAssertTrue(observations?.needsAnotherAngle ?? false)
    }
}

final class PhotoAnalysisMergerTests: XCTestCase {
    func testMergeCombinesOcrAndVlmObservations() {
        let ocr = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 800,
            height: 600,
            ocrText: "MODEL ABC-123",
            detectedLabels: ["label"]
        )
        let vlm = VisualObservations(
            visibleObjects: ["metal panel"],
            confidence: .low,
            needsAnotherAngle: true,
            summary: "Panel with readable label."
        )

        let merged = PhotoAnalysisMerger.merge(
            ocrAnalysis: ocr,
            vlmObservations: vlm,
            source: .ocrAndVlm
        )

        XCTAssertEqual(merged.ocrText, "MODEL ABC-123")
        XCTAssertEqual(merged.visualObservations?.summary, "Panel with readable label.")
        XCTAssertEqual(merged.visionAnalysisSource, .ocrAndVlm)
    }

    func testRetrievalQueryIncludesVlmTokens() {
        let analysis = PhotoAnalysisMerger.merge(
            ocrAnalysis: PhotoAnalysisResult(
                imagePath: "/tmp/photo.jpg",
                width: 800,
                height: 600,
                ocrText: "ABC-123",
                detectedLabels: ["label"]
            ),
            vlmObservations: VisualObservations(
                visibleObjects: ["pressure gauge"],
                possibleProblems: ["needle near red zone"],
                confidence: .medium,
                summary: "Gauge near upper range"
            ),
            source: .ocrAndVlm
        )

        let query = analysis.retrievalQuery(userQuestion: "Is this safe?", editedOcr: nil)
        XCTAssertTrue(query.contains("pressure gauge"))
        XCTAssertTrue(query.contains("Gauge near upper range"))
    }
}

final class PhotoObservationPromptTests: XCTestCase {
    func testPromptIncludesVlmBlockWhenPresent() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 640,
            height: 480,
            ocrText: "ABC-123",
            visualObservations: VisualObservations(
                visibleObjects: ["gauge"],
                confidence: .low,
                needsAnotherAngle: true,
                summary: "Gauge cluster"
            ),
            visionAnalysisSource: .ocrAndVlm
        )

        let block = analysis.promptBlock(editedOcr: nil)
        XCTAssertTrue(block.contains("Visual observations"))
        XCTAssertTrue(block.contains("Gauge cluster"))
        XCTAssertTrue(block.contains("experimental SmolVLM prototype"))
    }

    func testFallbackPromptWhenVlmUnavailable() {
        let analysis = PhotoAnalysisResult(
            imagePath: "/tmp/photo.jpg",
            width: 640,
            height: 480,
            ocrText: "ABC-123",
            visionAnalysisSource: .vlmUnavailable
        )

        let block = analysis.promptBlock(editedOcr: nil)
        XCTAssertTrue(block.contains("SmolVLM vision model is not available"))
        XCTAssertFalse(block.contains("Visual observations"))
    }

    func testCustomerAnalysisLabels() {
        XCTAssertEqual(VisionAnalysisSource.ocrOnly.customerAnalysisLabel, "OCR only")
        XCTAssertEqual(VisionAnalysisSource.ocrAndVlm.customerAnalysisLabel, "OCR + Visual Reasoning")
        XCTAssertEqual(VisionAnalysisSource.vlmUnavailable.customerAnalysisLabel, "OCR only")
        XCTAssertEqual(VisionAnalysisSource.vlmFailed.customerAnalysisLabel, "OCR only")
    }
}
