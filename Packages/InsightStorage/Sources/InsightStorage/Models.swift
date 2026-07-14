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
    public let imagePath: String?
    public let ocrText: String?
    public let visualObservationsJSON: String?
    public let locationJSON: String?
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
        imagePath: String? = nil,
        ocrText: String? = nil,
        visualObservationsJSON: String? = nil,
        locationJSON: String? = nil,
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
        self.imagePath = imagePath
        self.ocrText = ocrText
        self.visualObservationsJSON = visualObservationsJSON
        self.locationJSON = locationJSON
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

public struct KnowledgeVolumeRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let version: String?
    public let summary: String?
    public let tags: [String]
    public let sourceLabel: String?
    public let isEnabled: Bool
    public let installedAt: String

    public var resolvedVersion: String {
        guard let version = version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else {
            return "1.0"
        }
        return version
    }

    public init(
        id: String,
        title: String,
        version: String?,
        summary: String?,
        tags: [String],
        sourceLabel: String?,
        isEnabled: Bool,
        installedAt: String
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.summary = summary
        self.tags = tags
        self.sourceLabel = sourceLabel
        self.isEnabled = isEnabled
        self.installedAt = installedAt
    }
}

public struct StoredKnowledgeRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let volumeID: String
    public let title: String
    public let content: String
    public let tags: [String]

    public init(id: String, volumeID: String, title: String, content: String, tags: [String]) {
        self.id = id
        self.volumeID = volumeID
        self.title = title
        self.content = content
        self.tags = tags
    }
}

public struct MessageKnowledgeSourceRecord: Sendable, Equatable, Identifiable {
    public let id: String
    public let messageID: String
    public let volumeID: String
    public let volumeTitle: String
    public let recordID: String
    public let recordTitle: String
    public let excerpt: String

    public init(
        id: String,
        messageID: String,
        volumeID: String,
        volumeTitle: String,
        recordID: String,
        recordTitle: String,
        excerpt: String
    ) {
        self.id = id
        self.messageID = messageID
        self.volumeID = volumeID
        self.volumeTitle = volumeTitle
        self.recordID = recordID
        self.recordTitle = recordTitle
        self.excerpt = excerpt
    }
}

public struct UserProfileRecord: Sendable, Equatable {
    public let displayName: String?
    public let responseStyle: String?
    public let generalNotes: String?
    public let updatedAt: String

    public init(
        displayName: String?,
        responseStyle: String?,
        generalNotes: String?,
        updatedAt: String
    ) {
        self.displayName = displayName
        self.responseStyle = responseStyle
        self.generalNotes = generalNotes
        self.updatedAt = updatedAt
    }
}

public struct PersonalitySettingsRecord: Sendable, Equatable {
    public let activePresetID: String
    public let customPrompt: String?
    public let updatedAt: String

    public init(activePresetID: String, customPrompt: String?, updatedAt: String) {
        self.activePresetID = activePresetID
        self.customPrompt = customPrompt
        self.updatedAt = updatedAt
    }
}
