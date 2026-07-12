import Foundation

/// Structured on-device photo analysis. OCR from Apple Vision plus optional VLM observations.
public struct PhotoAnalysisResult: Sendable, Equatable {
    public let imagePath: String
    public let width: Int
    public let height: Int
    public let ocrText: String
    public let detectedLabels: [String]
    public let faceCount: Int
    public let barcodeCount: Int
    public let visualObservations: VisualObservations?
    public let visionAnalysisSource: VisionAnalysisSource

    public init(
        imagePath: String,
        width: Int,
        height: Int,
        ocrText: String,
        detectedLabels: [String] = [],
        faceCount: Int = 0,
        barcodeCount: Int = 0,
        visualObservations: VisualObservations? = nil,
        visionAnalysisSource: VisionAnalysisSource = .ocrOnly
    ) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
        self.ocrText = ocrText
        self.detectedLabels = detectedLabels
        self.faceCount = faceCount
        self.barcodeCount = barcodeCount
        self.visualObservations = visualObservations
        self.visionAnalysisSource = visionAnalysisSource
    }

    public func resolvedOcrText(edited: String?) -> String {
        let candidate = edited?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !candidate.isEmpty { return candidate }
        return ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func retrievalQuery(userQuestion: String, editedOcr: String?) -> String {
        var parts = [
            userQuestion,
            resolvedOcrText(edited: editedOcr),
            detectedLabels.joined(separator: " "),
        ]

        if let observations = visualObservations {
            parts.append(observations.summary)
            parts.append(observations.visibleObjects.joined(separator: " "))
            parts.append(observations.readableLabels.joined(separator: " "))
            parts.append(observations.possibleProblems.joined(separator: " "))
        }

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public func promptBlock(editedOcr: String?) -> String {
        PhotoObservationFormatter.promptBlock(for: self, editedOcr: editedOcr)
    }
}

public enum PhotoObservationFormatter {
    public static func promptBlock(for analysis: PhotoAnalysisResult, editedOcr: String?) -> String {
        let ocr = analysis.resolvedOcrText(edited: editedOcr)
        var lines: [String] = []

        switch analysis.visionAnalysisSource {
        case .ocrAndVlm:
            lines.append("These are locally extracted photo observations from Apple Vision OCR and an experimental on-device SmolVLM prototype.")
            lines.append("The VLM prototype may be incomplete or wrong — treat confidence and uncertainty notes seriously.")
        case .vlmFailed:
            lines.append("Apple Vision OCR succeeded, but the experimental SmolVLM prototype could not analyze this photo.")
            lines.append("Use OCR and metadata below; do not claim visual details beyond them.")
        case .vlmUnavailable:
            lines.append("These are locally extracted photo observations from Apple Vision OCR and basic image metadata.")
            lines.append("The experimental SmolVLM vision model is not available on this device yet.")
        case .ocrOnly:
            lines.append("These are locally extracted photo observations from Apple Vision OCR and basic image metadata.")
        }

        lines.append("Image size: \(analysis.width)x\(analysis.height) pixels.")

        if analysis.detectedLabels.isEmpty {
            lines.append("Detected categories: none with high confidence.")
        } else {
            lines.append("Detected categories: \(analysis.detectedLabels.joined(separator: ", ")).")
        }

        if ocr.isEmpty {
            lines.append("Extracted text (OCR): none detected.")
        } else {
            lines.append("Extracted text (OCR):\n\(ocr)")
        }

        if let observations = analysis.visualObservations, !observations.isEmpty {
            lines.append(contentsOf: visualObservationLines(observations))
        }

        var extras: [String] = []
        if analysis.barcodeCount > 0 {
            extras.append("\(analysis.barcodeCount) barcode region(s) detected")
        }
        if analysis.faceCount > 0 {
            extras.append("\(analysis.faceCount) face region(s) detected")
        }
        if !extras.isEmpty {
            lines.append("Other detections: \(extras.joined(separator: ", ")).")
        }

        lines.append("Use OCR and visual observation text as evidence. Do not invent details beyond them.")
        return lines.joined(separator: "\n")
    }

    private static func visualObservationLines(_ observations: VisualObservations) -> [String] {
        var lines = ["Visual observations (experimental SmolVLM prototype):"]

        if !observations.summary.isEmpty {
            lines.append("Summary: \(observations.summary)")
        }
        if !observations.visibleObjects.isEmpty {
            lines.append("Visible objects/parts: \(observations.visibleObjects.joined(separator: ", ")).")
        }
        if !observations.readableLabels.isEmpty {
            lines.append("Readable labels: \(observations.readableLabels.joined(separator: ", ")).")
        }
        if !observations.possibleProblems.isEmpty {
            lines.append("Possible problems: \(observations.possibleProblems.joined(separator: ", ")).")
        }

        lines.append("Confidence: \(observations.confidence.rawValue).")
        if observations.needsAnotherAngle {
            lines.append("Uncertainty: another angle or closer photo may be needed.")
        }
        return lines
    }
}
