import Foundation

/// Active photo attachment for the current conversation turn(s).
public struct VisualContext: Sendable, Equatable {
    public let analysis: PhotoAnalysisResult
    public var editedOcrText: String?

    public init(analysis: PhotoAnalysisResult, editedOcrText: String? = nil) {
        self.analysis = analysis
        self.editedOcrText = editedOcrText
    }

    public var imagePath: String { analysis.imagePath }

    /// Backward-compatible summary for UI chips.
    public var caption: String {
        let ocr = analysis.resolvedOcrText(edited: editedOcrText)
        if !ocr.isEmpty {
            let firstLine = ocr.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ocr
            return firstLine.count > 120 ? String(firstLine.prefix(117)) + "…" : firstLine
        }
        if !analysis.detectedLabels.isEmpty {
            return analysis.detectedLabels.prefix(3).joined(separator: ", ")
        }
        return "Photo attached (\(analysis.width)×\(analysis.height))"
    }

    public func promptBlock() -> String {
        analysis.promptBlock(editedOcr: editedOcrText)
    }

    public func withEditedOcr(_ text: String?) -> VisualContext {
        VisualContext(analysis: analysis, editedOcrText: text)
    }
}
