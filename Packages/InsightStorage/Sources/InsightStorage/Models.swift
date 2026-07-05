import Foundation

public struct SessionRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let startedAt: String
    public let endedAt: String?
    public let status: String

    public init(id: String, startedAt: String, endedAt: String?, status: String) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
    }
}

public struct MessageRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let sessionID: String
    public let timestamp: String
    public let role: String
    public let content: String
    public let source: String
    public let promptVersionID: String?
    public let latencyMs: Int?
    public let cancelled: Bool

    public init(
        id: String,
        sessionID: String,
        timestamp: String,
        role: String,
        content: String,
        source: String,
        promptVersionID: String?,
        latencyMs: Int?,
        cancelled: Bool
    ) {
        self.id = id
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.role = role
        self.content = content
        self.source = source
        self.promptVersionID = promptVersionID
        self.latencyMs = latencyMs
        self.cancelled = cancelled
    }
}

public struct PromptVersionRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let content: String
    public let label: String?
    public let createdAt: String
    public let isActive: Bool

    public init(id: String, content: String, label: String?, createdAt: String, isActive: Bool) {
        self.id = id
        self.content = content
        self.label = label
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

public struct MemoryFactRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let text: String
    public let createdAt: String
    public let active: Bool

    public init(id: String, text: String, createdAt: String, active: Bool) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.active = active
    }
}
