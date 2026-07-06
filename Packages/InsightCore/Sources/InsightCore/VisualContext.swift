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
        Factual image description for the currently attached photo. Use this as evidence only; do not invent details beyond it.
        \(caption)
        """
    }
}
