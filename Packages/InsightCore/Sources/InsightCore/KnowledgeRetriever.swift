import Foundation

/// Lightweight offline keyword/tag retrieval over installed knowledge volumes.
public struct KnowledgeRetriever: Sendable {
    public init() {}

    public func retrieve(
        query: String,
        volumes: [KnowledgeVolume],
        maxResults: Int = 4
    ) -> RetrievedKnowledgeContext {
        let queryGeoTags = geoTags(in: query)
        var queryTokens = keywords(in: query)
        for geoTag in queryGeoTags {
            queryTokens.insert(geoTag)
            let value = String(geoTag.dropFirst(4))
            queryTokens.insert(value)
            for part in value.split(separator: ",") {
                queryTokens.insert(String(part))
            }
        }
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
        let geographicOverlap = geographicScore(
            recordTags: tagTokens,
            volumeTags: volumeTags,
            queryTokens: queryTokens
        )

        return titleOverlap + tagOverlap + volumeTagOverlap + contentOverlap + geographicOverlap
    }

    private func geographicScore(
        recordTags: Set<String>,
        volumeTags: Set<String>,
        queryTokens: Set<String>
    ) -> Int {
        let geoTags = (recordTags.union(volumeTags)).filter { $0.hasPrefix("geo:") }
        guard !geoTags.isEmpty else { return 0 }

        var score = 0
        for geoTag in geoTags {
            let value = String(geoTag.dropFirst(4))
            if queryTokens.contains(value) || queryTokens.contains(geoTag) {
                score += 5
            }
            let parts = value.split(separator: ",").map(String.init)
            if parts.count == 2, queryTokens.contains(parts[0]) || queryTokens.contains(parts[1]) {
                score += 2
            }
        }
        return score
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

    private func geoTags(in text: String) -> Set<String> {
        var tags = Set<String>()
        let lowered = text.lowercased()
        var searchStart = lowered.startIndex

        while searchStart < lowered.endIndex {
            guard let geoRange = lowered[searchStart...].range(of: "geo:") else { break }
            let tagStart = geoRange.lowerBound
            var tagEnd = geoRange.upperBound

            while tagEnd < lowered.endIndex {
                let character = lowered[tagEnd]
                if character.isLetter || character.isNumber || character == "." || character == "," || character == "-" {
                    tagEnd = lowered.index(after: tagEnd)
                } else {
                    break
                }
            }

            tags.insert(String(lowered[tagStart..<tagEnd]))
            searchStart = tagEnd
        }

        return tags
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
