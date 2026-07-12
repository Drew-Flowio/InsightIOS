import Foundation

public enum MemoryCommand: Sendable, Equatable {
    case remember(fact: String)
    case recall(query: String?)
    case forget(target: String)
    case none
}

public struct MemoryCommandParser: Sendable {
    public init() {}

    public func parse(_ text: String) -> MemoryCommand {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }

        let lower = trimmed.lowercased()

        if let fact = extractPrefixedFact(from: trimmed, lower: lower, prefixes: [
            "remember that ",
            "please remember that ",
            "remember: ",
            "please remember: ",
        ]) {
            return fact.isEmpty ? .none : .remember(fact: fact)
        }

        if lower.hasPrefix("forget ") {
            let target = String(trimmed.dropFirst("forget ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { return .none }
            return .forget(target: target)
        }

        if lower.hasPrefix("forget that ") {
            let target = String(trimmed.dropFirst("forget that ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty else { return .none }
            return .forget(target: target)
        }

        if isRecallCommand(lower) {
            if lower.contains("about me") {
                return .recall(query: nil)
            }
            let query = extractRecallQuery(from: trimmed, lower: lower)
            return .recall(query: query)
        }

        return .none
    }

    private func extractPrefixedFact(from trimmed: String, lower: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            if lower.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func isRecallCommand(_ lower: String) -> Bool {
        lower.contains("what do you remember about me")
            || lower.contains("what do you remember about")
            || lower == "what do you remember"
            || lower == "what do you remember?"
            || lower.hasPrefix("what do you remember about me?")
            || lower.hasPrefix("what do you remember?")
    }

    private func extractRecallQuery(from trimmed: String, lower: String) -> String? {
        let markers = [
            "what do you remember about me regarding ",
            "what do you remember about ",
        ]
        for marker in markers {
            if lower.hasPrefix(marker) {
                let query = String(trimmed.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "?"))
                return query.isEmpty ? nil : query
            }
        }
        return nil
    }
}
