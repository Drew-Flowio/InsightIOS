import Foundation
import InsightCore
import InsightRuntime

/// Holds a reusable SmolVLM session so the runtime coordinator can prepare and unload it.
public actor SmolVlmVisionSessionHolder {
    private let modelPath: URL
    private let mmprojPath: URL
    private let config: VisionRuntimeConfig
    private var session: LlamaVisionSession?

    public init(modelPath: URL, mmprojPath: URL, config: VisionRuntimeConfig) {
        self.modelPath = modelPath
        self.mmprojPath = mmprojPath
        self.config = config
    }

    public var supportsVisualReasoning: Bool {
        ModelFileIntegrity.isValidModelFile(at: modelPath, expectedBytes: config.modelDiskBytes) &&
            ModelFileIntegrity.isValidModelFile(at: mmprojPath, expectedBytes: config.mmprojDiskBytes)
    }

    public var isLoaded: Bool {
        get async {
            guard let session else { return false }
            return await session.isLoaded
        }
    }

    public func prepare() async throws {
        guard supportsVisualReasoning else { return }
        if session == nil {
            session = LlamaVisionSession(modelPath: modelPath, mmprojPath: mmprojPath, config: config)
        }
        try await session?.prepareForInference()
    }

    public func unload() async {
        if let session {
            await session.unload()
        }
        session = nil
    }

    public func generateObservations(imageURL: URL) async -> VisualObservations? {
        guard supportsVisualReasoning else { return nil }
        if session == nil {
            session = LlamaVisionSession(modelPath: modelPath, mmprojPath: mmprojPath, config: config)
        }
        guard let session else { return nil }

        do {
            let json = try await session.generateObservationsJSON(imageURL: imageURL)
            return VisualObservationsParser().parse(json)
        } catch {
            LlamaRuntimeLog.info("SmolVLM observation failed: \(error.localizedDescription)")
            await unload()
            return nil
        }
    }
}

public struct CompositeVisionAnalyzer: VisionModelServing {
    private let ocrAnalyzer = SystemVisionImageAnalyzer()
    private let vlmHolder: SmolVlmVisionSessionHolder

    public init(modelPath: URL, mmprojPath: URL, config: VisionRuntimeConfig) {
        self.vlmHolder = SmolVlmVisionSessionHolder(
            modelPath: modelPath,
            mmprojPath: mmprojPath,
            config: config
        )
    }

    public var supportsVisualReasoning: Bool {
        get async { await vlmHolder.supportsVisualReasoning }
    }

    public var isLoaded: Bool {
        get async { await vlmHolder.isLoaded }
    }

    public func prepare() async throws {
        try await vlmHolder.prepare()
    }

    public func unload() async {
        await vlmHolder.unload()
    }

    public func analyzePhoto(at imageURL: URL) async throws -> PhotoAnalysisResult {
        try await analyzePhoto(at: imageURL, includeVisualReasoning: true)
    }

    public func analyzePhoto(at imageURL: URL, includeVisualReasoning: Bool) async throws -> PhotoAnalysisResult {
        let ocr = try await ocrAnalyzer.analyzePhoto(at: imageURL)

        guard includeVisualReasoning, await vlmHolder.supportsVisualReasoning else {
            return PhotoAnalysisMerger.merge(
                ocrAnalysis: ocr,
                vlmObservations: nil,
                source: .vlmUnavailable
            )
        }

        if let observations = await vlmHolder.generateObservations(imageURL: imageURL) {
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
