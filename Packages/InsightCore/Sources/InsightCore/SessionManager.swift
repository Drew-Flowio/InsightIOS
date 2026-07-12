import Foundation
import InsightStorage

/// Manages session-scoped chat history and prompt replay windowing.
public struct SessionManager: Sendable {
    private let repository: Repository
    private let historyTurnsInPrompt: Int
    public private(set) var currentSession: SessionRecord

    public init(repository: Repository, historyTurnsInPrompt: Int = 6) {
        self.repository = repository
        self.historyTurnsInPrompt = historyTurnsInPrompt
        self.currentSession = Self.resumeOrCreate(using: repository)
    }

    private static func resumeOrCreate(using repository: Repository) -> SessionRecord {
        repository.getLatestActiveSession() ?? repository.createSession()
    }

    @discardableResult
    public mutating func recordUserMessage(text: String, source: String = "text") -> MessageRecord {
        repository.addMessage(
            sessionID: currentSession.id,
            role: "user",
            content: text,
            source: source
        )
    }

    @discardableResult
    public mutating func recordPhotoQuestion(
        question: String,
        imagePath: String,
        ocrText: String,
        visualObservationsJSON: String? = nil
    ) -> MessageRecord {
        repository.addMessage(
            sessionID: currentSession.id,
            role: "user",
            content: question,
            source: "photo",
            imagePath: imagePath,
            ocrText: ocrText,
            visualObservationsJSON: visualObservationsJSON
        )
    }

    @discardableResult
    public mutating func recordAssistantMessage(
        text: String,
        promptVersionID: String?,
        latencyMs: Int,
        cancelled: Bool = false,
        knowledgeSources: [KnowledgeSourceAttribution] = []
    ) -> MessageRecord {
        let message = repository.addMessage(
            sessionID: currentSession.id,
            role: "assistant",
            content: text,
            source: "text",
            promptVersionID: promptVersionID,
            latencyMs: latencyMs,
            cancelled: cancelled
        )

        if !knowledgeSources.isEmpty {
            repository.addMessageKnowledgeSources(
                messageID: message.id,
                sources: knowledgeSources.map {
                    (
                        volumeID: $0.volumeID,
                        volumeTitle: $0.volumeTitle,
                        recordID: $0.recordID,
                        recordTitle: $0.recordTitle,
                        excerpt: $0.excerpt
                    )
                }
            )
        }

        return message
    }

    public func getAllMessages() -> [MessageRecord] {
        repository.getSessionMessages(sessionID: currentSession.id)
    }

    public func messageCount() -> Int {
        repository.countSessionMessages(sessionID: currentSession.id)
    }

    public func getPromptHistoryMessages() -> (messages: [ChatMessage], summaryNote: String?) {
        let messages = getAllMessages()
        let maxMessages = historyTurnsInPrompt * 2
        let recent = maxMessages > 0 ? Array(messages.suffix(maxMessages)) : messages
        let olderCount = max(0, messages.count - recent.count)

        let chatMessages = recent
            .filter { $0.role == "user" || $0.role == "assistant" }
            .map { ChatMessage(role: $0.role, content: $0.content) }

        let summaryNote: String? = olderCount > 0
            ? "(\(olderCount) earlier message(s) in this session are not shown verbatim.)"
            : nil

        return (chatMessages, summaryNote)
    }

    @discardableResult
    public mutating func reset(clearMemoryFacts: Bool = false) -> SessionRecord {
        repository.endSession(sessionID: currentSession.id)
        if clearMemoryFacts {
            repository.clearAllMemoryFacts()
        }
        currentSession = repository.createSession()
        return currentSession
    }
}
