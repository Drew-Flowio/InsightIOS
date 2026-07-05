import Foundation

enum ChatPreviewData {
    static let welcomeTitle = "Hey — I'm Insight."
    static let welcomeSubtitle = "Ask me anything, show me a photo, or tap the mic."

    static let sampleMessages: [ChatDisplayMessage] = [
        ChatDisplayMessage(
            role: .photo,
            content: "A stainless steel electric kettle on a kitchen counter. The power cord is plugged in.",
            imageURL: nil
        ),
        ChatDisplayMessage(
            role: .user,
            content: "Is this safe to touch right now?"
        ),
        ChatDisplayMessage(
            role: .assistant,
            content: "Hold up — if it's plugged in and was recently boiling, treat the body as hot. Unplug it first, then check the base."
        ),
        ChatDisplayMessage(
            role: .user,
            content: "It's been off for ten minutes."
        ),
        ChatDisplayMessage(
            role: .assistant,
            content: "You're probably fine on the handle, but touch the side lightly first. If it's warm, give it another few minutes.",
            isStreaming: false
        ),
    ]

    static let streamingAssistant = ChatDisplayMessage(
        id: "streaming",
        role: .assistant,
        content: "Yeah, that's the thermal fuse — pop the cover and",
        isStreaming: true
    )
}
