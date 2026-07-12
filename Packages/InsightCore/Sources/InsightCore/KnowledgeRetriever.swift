import Foundation

/// Lightweight offline keyword/tag retrieval over installed knowledge volumes.
public struct KnowledgeRetriever: Sendable {
    public init() {}

    public func retrieve(
        query: String,
        volumes: [KnowledgeVolume],
        maxResults: Int = 4
    ) -> RetrievedKnowledgeContext {
        let queryTokens = keywords(in: query)
        guard !queryTokens.isEmpty else { return RetrievedKnowledgeContext() }

        var scored: [(KnowledgeSourceAttribution, Int)] = []

        for volume in volumes {
            for record in volume.records {
                let score = scoreRecord(record, volume: volume, queryTokens: queryTokens)
                guard score > 0 else { continue }

                scored.append((
                    KnowledgeSourceAttribution(
                        volumeID: volume.id,
                        volumeTitle: volume.title,
                        recordID: record.id,
                        recordTitle: record.title,
                        excerpt: attributedExcerpt(for: record)
                    ),
                    score
                ))
            }
        }

        let hits = scored
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0.recordTitle.count < rhs.0.recordTitle.count }
                return lhs.1 > rhs.1
            }
            .prefix(maxResults)
            .map(\.0)

        return RetrievedKnowledgeContext(hits: Array(hits))
    }

    private func scoreRecord(
        _ record: KnowledgeRecord,
        volume: KnowledgeVolume,
        queryTokens: Set<String>
    ) -> Int {
        let titleTokens = keywords(in: record.title)
        let contentTokens = keywords(in: record.content)
        let tagTokens = Set(record.tags.map { $0.lowercased() })
        let volumeTags = Set(volume.tags.map { $0.lowercased() })

        let titleOverlap = queryTokens.intersection(titleTokens).count * 4
        let tagOverlap = queryTokens.intersection(tagTokens).count * 3
        let volumeTagOverlap = queryTokens.intersection(volumeTags).count
        let contentOverlap = queryTokens.intersection(contentTokens).count

        return titleOverlap + tagOverlap + volumeTagOverlap + contentOverlap
    }

    private func attributedExcerpt(for record: KnowledgeRecord) -> String {
        let body = excerpt(from: record.content)
        if let pageNumber = pageNumber(from: record.tags) {
            return "p. \(pageNumber) — \(body)"
        }
        return body
    }

    private func pageNumber(from tags: [String]) -> Int? {
        guard let tag = tags.first(where: { $0.hasPrefix("page:") }) else { return nil }
        return Int(tag.replacingOccurrences(of: "page:", with: ""))
    }

    private func excerpt(from content: String, limit: Int = 320) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func keywords(in text: String) -> Set<String> {
        let stopWords: Set<String> = [
            "about", "after", "again", "also", "and", "any", "are", "can", "could",
            "did", "does", "for", "from", "had", "has", "have", "how", "into",
            "is", "it", "its", "just", "like", "me", "my", "of", "on", "or",
            "our", "that", "the", "their", "them", "this", "to", "was", "what",
            "when", "where", "which", "with", "would", "you", "your", "why"
        ]

        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 && !stopWords.contains($0) }
        )
    }
}
