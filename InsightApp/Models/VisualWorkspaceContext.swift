import Foundation
import InsightCore

enum VisualWorkspaceVisual: Equatable, Sendable {
    case photo(URL)
    case map
    case manualPage(volumeID: String, volumeTitle: String, pageNumber: Int, pageCount: Int)
}

struct VisualWorkspaceContext: Identifiable, Equatable {
    let id: String
    let visual: VisualWorkspaceVisual
    let anchorMessageID: String?
    let photoObservations: String?

    init(
        id: String = UUID().uuidString,
        visual: VisualWorkspaceVisual,
        anchorMessageID: String? = nil,
        photoObservations: String? = nil
    ) {
        self.id = id
        self.visual = visual
        self.anchorMessageID = anchorMessageID
        self.photoObservations = photoObservations
    }
}
