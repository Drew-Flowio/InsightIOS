import Foundation
import InsightCore
import InsightRuntime

public struct SmolVlmVisionAnalyzer: Sendable {
    private let modelPath: URL
    private let mmprojPath: URL
    private let config: VisionRuntimeConfig

    public init(modelPath: URL, mmprojPath: URL, config: VisionRuntimeConfig) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.config = config
    }

    public var isAvailable: Bool {
        LlamaVisionSession.modelsAvailable(modelPath: modelPath, mmprojPath: mmprojPath)
    }

    public func generateObservations(imageURL: URL) async -> VisualObservations? {
        guard isAvailable else { return nil }
        let session = LlamaVisionSession(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            config: config
        )
        do {
            let json = try await session.generateObservationsJSON(imageURL: imageURL)
            return VisualObservationsParser().parse(json)
        } catch {
            LlamaRuntimeLog.info("SmolVLM observation failed: \(error.localizedDescription)")
            return nil
        }
    }
}

public struct CompositeVisionAnalyzer: VisionServing {
    private let ocrAnalyzer = SystemVisionImageAnalyzer()
    private let vlmAnalyzer: SmolVlmVisionAnalyzer?

    public init(modelPath: URL, mmprojPath: URL, config: VisionRuntimeConfig) {
        let analyzer = SmolVlmVisionAnalyzer(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            config: config
        )
        self.vlmAnalyzer = analyzer.isAvailable ? analyzer : nil
    }

    public func analyzePhoto(at imageURL: URL) async throws -> PhotoAnalysisResult {
        let ocr = try await ocrAnalyzer.analyzePhoto(at: imageURL)

        guard let vlmAnalyzer else {
            return PhotoAnalysisMerger.merge(
                ocrAnalysis: ocr,
                vlmObservations: nil,
                source: .vlmUnavailable
            )
        }

        if let observations = await vlmAnalyzer.generateObservations(imageURL: imageURL) {
            return PhotoAnalysisMerger.merge(
                ocrAnalysis: ocr,
                vlmObservations: observations,
                source: .ocrAndVlm
            )
        }

        return PhotoAnalysisMerger.merge(
            ocrAnalysis: ocr,
            vlmObservations: nil,
            source: .vlmFailed
        )
    }

    public func describeImage(at imageURL: URL) async throws -> String {
        let analysis = try await analyzePhoto(at: imageURL)
        return analysis.promptBlock(editedOcr: nil)
    }
}
