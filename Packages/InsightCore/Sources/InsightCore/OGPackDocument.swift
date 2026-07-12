import Foundation

/// Minimal `.ogpack` import document. JSON payload today; other formats can map here later.
public struct OGPackDocument: Sendable, Equatable, Codable {
    public let formatVersion: Int
    public let volume: OGPackVolume
    public let records: [OGPackRecord]

    public init(formatVersion: Int, volume: OGPackVolume, records: [OGPackRecord]) {
        self.formatVersion = formatVersion
        self.volume = volume
        self.records = records
    }

    public func asKnowledgeVolume() -> KnowledgeVolume {
        KnowledgeVolume(
            id: volume.id,
            title: volume.title,
            version: volume.resolvedVersion,
            summary: volume.summary,
            tags: volume.tags,
            records: records.map {
                KnowledgeRecord(id: $0.id, title: $0.title, content: $0.content, tags: $0.tags)
            }
        )
    }
}

public struct OGPackVolume: Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let version: String?
    public let summary: String?
    public let tags: [String]

    public init(
        id: String,
        title: String,
        version: String? = nil,
        summary: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.summary = summary
        self.tags = tags
    }

    var resolvedVersion: String {
        guard let version = version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty else {
            return "1.0"
        }
        return version
    }
}

public struct OGPackRecord: Sendable, Equatable, Codable {
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

public enum OGPackParser {
    public enum Error: Swift.Error, Equatable {
        case unsupportedFormatVersion(Int)
        case missingVolume
        case emptyRecords
    }

    public static func parse(data: Data) throws -> KnowledgeVolume {
        let decoder = JSONDecoder()
        let document = try decoder.decode(OGPackDocument.self, from: data)

        guard document.formatVersion == 1 else {
            throw Error.unsupportedFormatVersion(document.formatVersion)
        }
        guard !document.volume.id.isEmpty, !document.volume.title.isEmpty else {
            throw Error.missingVolume
        }
        guard !document.records.isEmpty else {
            throw Error.emptyRecords
        }

        return document.asKnowledgeVolume()
    }
}
