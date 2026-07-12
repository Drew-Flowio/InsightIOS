import CoreGraphics
import Foundation
import ImageIO
import InsightCore
import Vision

public struct SystemVisionImageAnalyzer: VisionServing {
    public init() {}

    public func analyzePhoto(at imageURL: URL) async throws -> PhotoAnalysisResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.analyzePhoto(at: imageURL)
        }.value
    }

    public func describeImage(at imageURL: URL) async throws -> String {
        let analysis = try await analyzePhoto(at: imageURL)
        return analysis.promptBlock(editedOcr: nil)
    }

    private static func analyzePhoto(at imageURL: URL) throws -> PhotoAnalysisResult {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return PhotoAnalysisResult(
                imagePath: imageURL.path,
                width: 0,
                height: 0,
                ocrText: "",
                detectedLabels: []
            )
        }

        let classifyRequest = VNClassifyImageRequest()
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.minimumTextHeight = 0.015

        let faceRequest = VNDetectFaceRectanglesRequest()
        let barcodeRequest = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([classifyRequest, textRequest, faceRequest, barcodeRequest])

        let labels = (classifyRequest.results ?? [])
            .filter { $0.confidence >= 0.10 }
            .prefix(8)
            .map { cleanIdentifier($0.identifier) }

        let textLines = (textRequest.results ?? [])
            .compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.35 else { return nil }
                return candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return PhotoAnalysisResult(
            imagePath: imageURL.path,
            width: image.width,
            height: image.height,
            ocrText: textLines.prefix(24).joined(separator: "\n"),
            detectedLabels: Array(labels),
            faceCount: faceRequest.results?.count ?? 0,
            barcodeCount: barcodeRequest.results?.count ?? 0
        )
    }

    private static func cleanIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ",", with: " / ")
    }
}
