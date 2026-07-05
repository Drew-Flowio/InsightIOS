import Foundation
import InsightCore
import InsightRuntime

public final class LlamaCppLlmAdapter: LlmServing, @unchecked Sendable {
    private let session: LlamaSession

    public init(modelPath: URL, runtimeConfig: LlmRuntimeConfig) {
        session = LlamaSession(modelPath: modelPath, runtimeConfig: runtimeConfig)
    }

    public func prepare() async throws {
        try await session.prepare()
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
