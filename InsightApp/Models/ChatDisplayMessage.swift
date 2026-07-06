import Foundation

enum ChatMessageRole: String, Sendable {
    case user
    case assistant
    case photo
}

struct ChatDisplayMessage: Identifiable, Equatable, Sendable {
    let id: String
    let role: ChatMessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var imageURL: URL?

    init(
        id: String = UUID().uuidString,
        role: ChatMessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageURL = imageURL
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}
