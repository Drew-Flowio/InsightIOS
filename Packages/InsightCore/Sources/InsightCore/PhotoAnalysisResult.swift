import Foundation

/// Structured on-device photo analysis. OCR and metadata — not direct model vision.
public struct PhotoAnalysisResult: Sendable, Equatable {
    public let imagePath: String
    public let width: Int
    public let height: Int
    public let ocrText: String
    public let detectedLabels: [String]
    public let faceCount: Int
    public let barcodeCount: Int

    public init(
        imagePath: String,
        width: Int,
        height: Int,
        ocrText: String,
        detectedLabels: [String] = [],
        faceCount: Int = 0,
        barcodeCount: Int = 0
    ) {
        self.imagePath = imagePath
        self.width = width
        self.height = height
        self.ocrText = ocrText
        self.detectedLabels = detectedLabels
        self.faceCount = faceCount
        self.barcodeCount = barcodeCount
    }

    public func resolvedOcrText(edited: String?) -> String {
        let candidate = edited?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !candidate.isEmpty { return candidate }
        return ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func retrievalQuery(userQuestion: String, editedOcr: String?) -> String {
        let parts = [
            userQuestion,
            resolvedOcrText(edited: editedOcr),
            detectedLabels.joined(separator: " "),
        ]
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
        lines.append("The assistant cannot see the image directly.")
        lines.append("These are locally extracted photo observations from Apple Vision OCR and basic image metadata.")
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

        lines.append("Treat OCR text as the primary evidence for labels, model numbers, warning codes, names, and document wording.")
        lines.append("Do not claim to see colors, damage, or details that are not supported by the extracted text or metadata above.")
        return lines.joined(separator: "\n")
    }
}
