import Foundation

public enum ManualPageReference {
    public static func pageNumber(fromRecordID recordID: String) -> Int? {
        guard recordID.hasPrefix("page.") else { return nil }
        return Int(recordID.dropFirst(5))
    }

    public static func isManualVolumeID(_ volumeID: String) -> Bool {
        volumeID.contains("manual")
    }
}

public enum VisualWorkspaceKind: String, Sendable, Equatable {
    case photo
    case map
    case manualPage
}
