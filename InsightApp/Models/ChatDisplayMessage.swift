import Foundation
import InsightCore

enum ChatMessageRole: String, Sendable {
    case user
    case assistant
    case photo
}

struct KnowledgeSourceDisplay: Identifiable, Equatable, Sendable {
    let id: String
    let volumeID: String
    let recordID: String
    let volumeTitle: String
    let recordTitle: String
    let excerpt: String

    var manualPageNumber: Int? {
        ManualPageReference.pageNumber(fromRecordID: recordID)
    }

    var isManualSource: Bool {
        manualPageNumber != nil || ManualPageReference.isManualVolumeID(volumeID)
    }
}

struct ChatDisplayMessage: Identifiable, Equatable, Sendable {
    let id: String
    let role: ChatMessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var imageURL: URL?
    var knowledgeSources: [KnowledgeSourceDisplay]
    var locationLabel: String?
    var photoObservationsText: String?
    var photoOcrText: String?

    init(
        id: String = UUID().uuidString,
        role: ChatMessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        imageURL: URL? = nil,
        knowledgeSources: [KnowledgeSourceDisplay] = [],
        locationLabel: String? = nil,
        photoObservationsText: String? = nil,
        photoOcrText: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageURL = imageURL
        self.knowledgeSources = knowledgeSources
        self.locationLabel = locationLabel
        self.photoObservationsText = photoObservationsText
        self.photoOcrText = photoOcrText
    }

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }
}
