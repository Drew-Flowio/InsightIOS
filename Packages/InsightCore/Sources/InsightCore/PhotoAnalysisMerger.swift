import Foundation

public enum PhotoAnalysisMerger {
    public static func merge(
        ocrAnalysis: PhotoAnalysisResult,
        vlmObservations: VisualObservations?,
        source: VisionAnalysisSource
    ) -> PhotoAnalysisResult {
        PhotoAnalysisResult(
            imagePath: ocrAnalysis.imagePath,
            width: ocrAnalysis.width,
            height: ocrAnalysis.height,
            ocrText: ocrAnalysis.ocrText,
            detectedLabels: ocrAnalysis.detectedLabels,
            faceCount: ocrAnalysis.faceCount,
            barcodeCount: ocrAnalysis.barcodeCount,
            visualObservations: vlmObservations,
            visionAnalysisSource: source
        )
    }
}
