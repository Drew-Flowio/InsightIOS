import Foundation
import InsightLlama

public enum InsightModelSetup {
    public static func isLLMReady(for configuration: AppConfiguration) -> Bool {
        configuration.modelStore.isLLMReady
    }

    public static func isWhisperReady(for configuration: AppConfiguration) -> Bool {
        configuration.modelStore.isWhisperReady
    }

    public static func isVoiceInputReady(for configuration: AppConfiguration) -> Bool {
        configuration.modelStore.isVoiceStackReady
    }

    public static func downloadLLM(
        for configuration: AppConfiguration,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        try await ModelDownloadService.downloadLLM(
            bundle: configuration.modelBundle,
            to: configuration.modelsDirectoryURL,
            onProgress: onProgress
        )
    }

    public static func downloadWhisper(
        for configuration: AppConfiguration,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws -> URL {
        try await ModelDownloadService.downloadWhisper(
            bundle: configuration.modelBundle,
            to: configuration.modelsDirectoryURL,
            onProgress: onProgress
        )
    }

    public static func downloadVoiceModels(
        for configuration: AppConfiguration,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws {
        _ = try await downloadWhisper(for: configuration, onProgress: onProgress)
    }

    public static func isVisionReady(for configuration: AppConfiguration) -> Bool {
        configuration.modelStore.isVisionReady
    }

    public static func downloadVision(
        for configuration: AppConfiguration,
        onProgress: (@Sendable (ModelDownloadProgress) -> Void)? = nil
    ) async throws {
        try await ModelDownloadService.downloadVision(
            bundle: configuration.modelBundle,
            to: configuration.modelsDirectoryURL,
            onProgress: onProgress
        )
    }

    public static func removeVisionModels(for configuration: AppConfiguration) throws {
        try ModelDownloadService.removeVisionModels(
            bundle: configuration.modelBundle,
            from: configuration.modelsDirectoryURL
        )
    }
}
