import Foundation

/// User-facing summary of an installed knowledge volume.
public struct MindLibraryItem: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let version: String
    public let summary: String
    public let isEnabled: Bool
    public let recordCount: Int

    public init(
        id: String,
        title: String,
        version: String,
        summary: String,
        isEnabled: Bool,
        recordCount: Int
    ) {
        self.id = id
        self.title = title
        self.version = version
        self.summary = summary
        self.isEnabled = isEnabled
        self.recordCount = recordCount
    }
}

public enum MindImportOutcome: Sendable, Equatable {
    case imported(title: String)
    case duplicate(title: String)
    case failed(message: String)
}

public struct LibraryStorageSummary: Sendable, Equatable {
    public let totalMinds: Int
    public let manualCount: Int
    public let importedDataCount: Int
    public let bundledMindCount: Int

    public init(
        totalMinds: Int,
        manualCount: Int,
        importedDataCount: Int,
        bundledMindCount: Int
    ) {
        self.totalMinds = totalMinds
        self.manualCount = manualCount
        self.importedDataCount = importedDataCount
        self.bundledMindCount = bundledMindCount
    }
}
