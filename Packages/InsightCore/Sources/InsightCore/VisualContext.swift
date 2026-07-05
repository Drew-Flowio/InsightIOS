import Foundation

/// Active photo context for the current conversation.
public struct VisualContext: Sendable, Equatable {
    public let imagePath: String
    public let caption: String

    public init(imagePath: String, caption: String) {
        self.imagePath = imagePath
        self.caption = caption
    }

    public func promptBlock() -> String {
        """
        What the user is showing you (from their attached photo — keep this in mind for follow-up questions until they attach a new photo):
        \(caption)
        """
    }
}
