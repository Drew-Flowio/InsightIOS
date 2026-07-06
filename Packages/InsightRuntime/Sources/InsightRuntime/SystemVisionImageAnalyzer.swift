import CoreGraphics
import Foundation
import ImageIO
import Vision

public struct SystemVisionImageAnalyzer: VisionServing {
    public init() {}

    public func describeImage(at imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try Self.analyzeImage(at: imageURL)
        }.value
    }

    private static func analyzeImage(at imageURL: URL) throws -> String {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return "Unable to analyze this image because it could not be loaded."
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

        let classifications = (classifyRequest.results ?? [])
            .filter { $0.confidence >= 0.10 }
            .prefix(8)
            .map { VisionLabel(name: cleanIdentifier($0.identifier), confidence: Double($0.confidence)) }

        let textLines = (textRequest.results ?? [])
            .compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.35 else { return nil }
                return candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        let faceCount = faceRequest.results?.count ?? 0
        let barcodeCount = barcodeRequest.results?.count ?? 0
        let confidence = imageConfidence(classifications: Array(classifications), textLines: textLines)

        return buildDescription(
            width: image.width,
            height: image.height,
            classifications: Array(classifications),
            textLines: Array(textLines.prefix(12)),
            faceCount: faceCount,
            barcodeCount: barcodeCount,
            confidence: confidence
        )
    }

    private static func buildDescription(
        width: Int,
        height: Int,
        classifications: [VisionLabel],
        textLines: [String],
        faceCount: Int,
        barcodeCount: Int,
        confidence: String
    ) -> String {
        var lines: [String] = []
        lines.append("Factual image description generated before answering.")
        lines.append("Image size: \(width)x\(height) pixels.")

        if classifications.isEmpty {
            lines.append("Main visible objects: Vision did not produce confident object/category labels.")
        } else {
            let labels = classifications
                .map { "\($0.name) (\(Int($0.confidence * 100))%)" }
                .joined(separator: ", ")
            lines.append("Main visible objects/categories detected: \(labels). Treat these as machine-vision clues, not guaranteed facts.")
        }

        if textLines.isEmpty {
            lines.append("Text visible in the image: No readable text detected.")
        } else {
            lines.append("Text visible in the image: \(textLines.joined(separator: " | ")).")
        }

        var environmentDetails: [String] = []
        if faceCount > 0 {
            environmentDetails.append("\(faceCount) face region(s) detected")
        }
        if barcodeCount > 0 {
            environmentDetails.append("\(barcodeCount) barcode region(s) detected")
        }
        lines.append("Environment/context: \(environmentDetails.isEmpty ? "No specific environment was confidently determined." : environmentDetails.joined(separator: ", ")).")
        lines.append("Condition/state of objects: Not reliably determined unless stated by detected labels or readable text above.")
        lines.append("Uncertainty: \(confidence). Do not infer hidden damage, model numbers, safety status, ingredients, wiring, or causes from this image alone.")
        lines.append("Things that cannot be determined: unseen sides, internal condition, exact materials, measurements, live electrical state, gas/chemical exposure, freshness, identity, and whether a device is safe to use.")
        return lines.joined(separator: "\n")
    }

    private static func imageConfidence(classifications: [VisionLabel], textLines: [String]) -> String {
        let best = classifications.first?.confidence ?? 0
        if best >= 0.55 || !textLines.isEmpty {
            return "Medium confidence. Use detected text and high-confidence labels, but ask for another angle for precise diagnosis."
        }
        if best >= 0.25 {
            return "Low-to-medium confidence. The image gives weak category clues but not enough for a firm diagnosis."
        }
        return "Low confidence. Ask for a clearer, closer photo before making image-specific claims."
    }

    private static func cleanIdentifier(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ",", with: " / ")
    }
}

private struct VisionLabel {
    let name: String
    let confidence: Double
}
