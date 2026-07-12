import Foundation

/// Domain-neutral local knowledge volume (Mind) independent of import format.
public struct KnowledgeVolume: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let summary: String?
    public let tags: [String]
    public let records: [KnowledgeRecord]

    public init(
        id: String,
        title: String,
        summary: String? = nil,
        tags: [String] = [],
        records: [KnowledgeRecord]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.tags = tags
        self.records = records
    }
}

public struct KnowledgeRecord: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let title: String
    public let content: String
    public let tags: [String]

    public init(id: String, title: String, content: String, tags: [String] = []) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
    }
}

public struct KnowledgeSourceAttribution: Sendable, Equatable, Identifiable, Codable {
    public let volumeID: String
    public let volumeTitle: String
    public let recordID: String
    public let recordTitle: String
    public let excerpt: String

    public var id: String { "\(volumeID)/\(recordID)" }

    public init(
        volumeID: String,
        volumeTitle: String,
        recordID: String,
        recordTitle: String,
        excerpt: String
    ) {
        self.volumeID = volumeID
        self.volumeTitle = volumeTitle
        self.recordID = recordID
        self.recordTitle = recordTitle
        self.excerpt = excerpt
    }
}

public struct RetrievedKnowledgeContext: Sendable, Equatable {
    public let hits: [KnowledgeSourceAttribution]

    public init(hits: [KnowledgeSourceAttribution] = []) {
        self.hits = hits
    }

    public var isEmpty: Bool { hits.isEmpty }

    public func promptBlock() -> String {
        guard !hits.isEmpty else { return "No matching knowledge records." }

        return hits.map { hit in
            """
            [\(hit.volumeTitle) · \(hit.recordTitle)]
            \(hit.excerpt)
            """
        }.joined(separator: "\n\n")
    }
}
