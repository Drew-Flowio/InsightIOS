import Foundation
import InsightCore
import InsightRuntime

public final class LlamaCppLlmAdapter: LlmServing, @unchecked Sendable {
    private let session: LlamaSession
    public let backendDebugDescription: String

    public init(modelPath: URL, runtimeConfig: LlmRuntimeConfig) {
        let backendSelection = LlamaBackendSelection.select(from: runtimeConfig)
        self.backendDebugDescription = backendSelection.debugDescription
        session = LlamaSession(modelPath: modelPath, backendSelection: backendSelection)
    }

    public func prepare() async throws {
        try await session.prepare()
    }

    public func unload() async {
        await session.unload()
    }

    public var isLoaded: Bool {
        get async { await session.isLoaded }
    }

    public func generate(
        messages: [ChatMessage],
        onToken: (@Sendable (String) -> Void)?,
        shouldCancel: (@Sendable () -> Bool)?
    ) async throws -> String {
        try await session.generate(
            messages: messages,
            onToken: onToken,
            shouldCancel: shouldCancel
        )
    }
}
