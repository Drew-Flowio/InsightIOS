import Foundation

public struct PersonalMemoryRetriever: Sendable {
    public init() {}

    public func retrieve(facts: [String], for query: String) -> RelevantMemoryContext {
        guard !facts.isEmpty else { return RelevantMemoryContext() }

        let questionTokens = Self.keywords(in: query)
        let scoredFacts = facts.compactMap { fact -> (text: String, score: Int, category: MemoryCategory)? in
            let category = Self.category(forMemoryFact: fact)
            let factTokens = Self.keywords(in: fact)
            let overlap = questionTokens.intersection(factTokens).count
            let alwaysUsefulPreference = category == .preference && Self.isAnswerStylePreference(fact)
            let score = overlap + (alwaysUsefulPreference ? 2 : 0)
            guard score > 0 else { return nil }
            return (fact, score, category)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.text.count < rhs.text.count }
            return lhs.score > rhs.score
        }
        .prefix(8)

        var preferences: [String] = []
        var userFacts: [String] = []
        var pastContext: [String] = []

        for item in scoredFacts {
            switch item.category {
            case .preference:
                preferences.append(item.text)
            case .userFact:
                userFacts.append(item.text)
            case .pastContext:
                pastContext.append(item.text)
            }
        }

        return RelevantMemoryContext(
            userPreferences: Array(preferences.prefix(3)),
            userFacts: Array(userFacts.prefix(3)),
            pastConversationContext: Array(pastContext.prefix(2))
        )
    }

    public func matchingFactTexts(facts: [String], target: String) -> [String] {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedTarget == "everything" || normalizedTarget == "all" || normalizedTarget == "all my memories" {
            return facts
        }

        let targetTokens = Self.keywords(in: target)
        guard !targetTokens.isEmpty else { return [] }

        return facts.filter { fact in
            let factTokens = Self.keywords(in: fact)
            return !targetTokens.intersection(factTokens).isEmpty
        }
    }

    public func isValidMemoryFact(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 500 else { return false }

        let lower = trimmed.lowercased()
        let blockedMarkers = [
            "knowledge volume",
            "page:",
            "sources used",
            "retrieved from",
            "according to the manual",
        ]
        return !blockedMarkers.contains(where: lower.contains)
    }

    public func formatRecallReply(
        facts: [String],
        profile: UserProfileContext,
        query: String?
    ) -> String {
        let filtered: [String]
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = matchingFactTexts(facts: facts, target: query)
        } else {
            filtered = facts
        }

        var sections: [String] = []
        if !profile.isEmpty {
            sections.append("Profile:\n\(profile.promptBlock())")
        }

        if filtered.isEmpty {
            if query != nil {
                sections.append("I don't have any saved memories about that yet.")
            } else {
                sections.append("I don't have any saved personal memories yet.")
            }
        } else {
            let list = filtered.map { "- \($0)" }.joined(separator: "\n")
            sections.append("Saved memories:\n\(list)")
        }

        return sections.joined(separator: "\n\n")
    }

    private enum MemoryCategory {
        case preference
        case userFact
        case pastContext
    }

    private static func category(forMemoryFact fact: String) -> MemoryCategory {
        let lower = fact.lowercased()
        let preferenceMarkers = [
            "prefers", "preference", "likes", "dislikes", "wants",
            "answer style", "concise", "brief", "detailed", "units", "metric", "imperial",
        ]
        if preferenceMarkers.contains(where: lower.contains) {
            return .preference
        }

        let userFactMarkers = [
            "user is", "user has", "user owns", "user works", "user lives",
            "my ", "i am", "i have", "i own",
        ]
        if userFactMarkers.contains(where: lower.contains) {
            return .userFact
        }

        return .pastContext
    }

    private static func isAnswerStylePreference(_ fact: String) -> Bool {
        let lower = fact.lowercased()
        return lower.contains("answer")
            || lower.contains("concise")
            || lower.contains("brief")
            || lower.contains("detailed")
            || lower.contains("metric")
            || lower.contains("imperial")
            || lower.contains("units")
    }

    private static func keywords(in text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "and", "any", "are", "can", "could",
            "did", "does", "for", "from", "had", "has", "have", "how", "into",
            "is", "it", "its", "just", "like", "me", "my", "of", "on", "or",
            "our", "that", "the", "their", "them", "this", "to", "was", "what",
            "when", "where", "which", "with", "would", "you", "your", "remember", "forget",
        ]

        let separators = CharacterSet.alphanumerics.inverted
        return Set(
            text.lowercased()
                .components(separatedBy: separators)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
        )
    }
}
