import Foundation

enum ChatMessageRole: String, Sendable {
    case user
    case assistant
    case photo
}

struct KnowledgeSourceDisplay: Identifiable, Equatable, Sendable {
    let id: String
    let volumeTitle: String
    let recordTitle: String
    let excerpt: String
}

struct ChatDisplayMessage: Identifiable, Equatable, Sendable {
    let id: String
    let role: ChatMessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var imageURL: URL?
    var knowledgeSources: [KnowledgeSourceDisplay]

    init(
        id: String = UUID().uuidString,
        role: ChatMessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageURL: URL? = nil,
        knowledgeSources: [KnowledgeSourceDisplay] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageURL = imageURL
        self.knowledgeSources = knowledgeSources
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}
