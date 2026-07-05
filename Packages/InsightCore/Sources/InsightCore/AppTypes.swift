import Foundation

/// Every state the status area in the UI can show.
public enum AppState: String, Sendable, CaseIterable {
    case idle
    case listening
    case transcribing
    case analyzing
    case thinking
    case speaking
    case error
}

/// A read-only snapshot of engine state for the inspector panel.
public struct SessionStateView: Sendable {
    public let sessionID: String
    public let messageCount: Int
    public let activePromptLabel: String?
    public let activePromptVersionID: String?
    public let memoryFactCount: Int
    public let currentState: AppState
    public let sessionSummary: String

    public init(
        sessionID: String,
        messageCount: Int,
        activePromptLabel: String?,
        activePromptVersionID: String?,
        memoryFactCount: Int,
        currentState: AppState,
        sessionSummary: String
    ) {
        self.sessionID = sessionID
        self.messageCount = messageCount
        self.activePromptLabel = activePromptLabel
        self.activePromptVersionID = activePromptVersionID
        self.memoryFactCount = memoryFactCount
        self.currentState = currentState
        self.sessionSummary = sessionSummary
    }
}

/// What a completed (or cancelled) turn produced.
public struct TurnResult: Sendable {
    public let transcript: String?
    public let replyText: String
    public let cancelled: Bool
    public let latencyMs: Int
    public let promptVersionID: String?
    public let assembledPromptDebug: String
    public let imageCaption: String?

    public init(
        transcript: String? = nil,
        replyText: String,
        cancelled: Bool,
        latencyMs: Int,
        promptVersionID: String?,
        assembledPromptDebug: String = "",
        imageCaption: String? = nil
    ) {
        self.transcript = transcript
        self.replyText = replyText
        self.cancelled = cancelled
        self.latencyMs = latencyMs
        self.promptVersionID = promptVersionID
        self.assembledPromptDebug = assembledPromptDebug
        self.imageCaption = imageCaption
    }
}

public struct ChatMessage: Sendable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
