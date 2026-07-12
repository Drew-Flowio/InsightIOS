import Foundation

public struct UserProfileContext: Sendable, Equatable {
    public let displayName: String?
    public let responseStyle: String?
    public let generalNotes: String?

    public init(displayName: String? = nil, responseStyle: String? = nil, generalNotes: String? = nil) {
        self.displayName = displayName
        self.responseStyle = responseStyle
        self.generalNotes = generalNotes
    }

    public var isEmpty: Bool {
        clean(displayName) == nil && clean(responseStyle) == nil && clean(generalNotes) == nil
    }

    public func promptBlock() -> String {
        guard !isEmpty else { return "No user profile set." }

        var lines: [String] = []
        if let name = clean(displayName) {
            lines.append("Name: \(name)")
        }
        if let style = clean(responseStyle) {
            lines.append("Preferred response style: \(Self.styleDescription(for: style))")
        }
        if let notes = clean(generalNotes) {
            lines.append("General notes: \(notes)")
        }
        return lines.joined(separator: "\n")
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func styleDescription(for style: String) -> String {
        switch style.lowercased() {
        case "concise":
            return "Give concise, direct answers."
        case "detailed":
            return "Give thorough, detailed explanations."
        case "technical":
            return "Use precise technical language when helpful."
        case "casual":
            return "Keep a friendly, conversational tone."
        default:
            return "Balanced — clear and practical."
        }
    }
}
