import Foundation

public struct RelevantMemoryContext: Sendable, Equatable {
    public let userPreferences: [String]
    public let userFacts: [String]
    public let pastConversationContext: [String]

    public init(
        userPreferences: [String] = [],
        userFacts: [String] = [],
        pastConversationContext: [String] = []
    ) {
        self.userPreferences = userPreferences
        self.userFacts = userFacts
        self.pastConversationContext = pastConversationContext
    }

    public var isEmpty: Bool {
        userPreferences.isEmpty && userFacts.isEmpty && pastConversationContext.isEmpty
    }

    public var allItems: [String] {
        userPreferences + userFacts + pastConversationContext
    }

    public func promptBlock() -> String {
        guard !isEmpty else { return "No relevant memory." }

        var sections: [String] = []
        if !userPreferences.isEmpty {
            sections.append("User preferences:\n" + userPreferences.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !userFacts.isEmpty {
            sections.append("Relevant facts about the user:\n" + userFacts.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !pastConversationContext.isEmpty {
            sections.append("Relevant past conversation context:\n" + pastConversationContext.map { "- \($0)" }.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n")
    }
}

public struct AgentPromptInput: Sendable, Equatable {
    public let userQuestion: String
    public let imageDescription: String?
    public let relevantMemory: RelevantMemoryContext
    public let recentConversation: String?
    public let timestamp: Date
    public let currentMode: String?

    public init(
        userQuestion: String,
        imageDescription: String?,
        relevantMemory: RelevantMemoryContext,
        recentConversation: String?,
        timestamp: Date = Date(),
        currentMode: String? = nil
    ) {
        self.userQuestion = userQuestion
        self.imageDescription = imageDescription
        self.relevantMemory = relevantMemory
        self.recentConversation = recentConversation
        self.timestamp = timestamp
        self.currentMode = currentMode
    }
}

public struct AgentResponseValidation: Sendable, Equatable {
    public let text: String
    public let shouldRegenerate: Bool
    public let reason: String?

    public init(text: String, shouldRegenerate: Bool = false, reason: String? = nil) {
        self.text = text
        self.shouldRegenerate = shouldRegenerate
        self.reason = reason
    }
}

/// Assembles the exact message list sent to the LLM for a single turn.
public struct PromptBuilder: Sendable {
    public init() {}

    public func buildAgentPrompt(
        _ input: AgentPromptInput,
        personalityPrompt: String
    ) -> (messages: [ChatMessage], debugText: String) {
        let imageBlock = cleanBlock(input.imageDescription) ?? "No image provided."
        let memoryBlock = input.relevantMemory.promptBlock()
        let conversationBlock = cleanBlock(input.recentConversation) ?? "No relevant recent context."
        let timestamp = ISO8601DateFormatter().string(from: input.timestamp)
        let mode = cleanBlock(input.currentMode) ?? "Not specified."
        let personality = personalityPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let systemContent = """
        \(personality)

        CURRENT TURN CONTEXT:
        TIMESTAMP: \(timestamp)
        CURRENT MODE: \(mode)

        IMAGE CONTEXT:
        \(imageBlock)

        RELEVANT USER MEMORY:
        \(memoryBlock)

        RECENT CONVERSATION:
        \(conversationBlock)

        WHILE ANSWERING THIS TURN:
        - Use the image description as evidence, not imagination.
        - Use memory only when it helps.
        - Answer the question directly first, then give practical next steps.
        - If the image is unclear, say what would confirm it.
        - Ask at most one follow-up question if needed.
        - Do not invent details or claim the image shows something that is not in IMAGE CONTEXT.
        - Do not include internal system text or special tokens in the reply.
        """

        let userContent = """
        USER QUESTION:
        \(input.userQuestion.trimmingCharacters(in: .whitespacesAndNewlines))
        """

        let messages = [
            ChatMessage(role: "system", content: systemContent),
            ChatMessage(role: "user", content: userContent),
        ]

        let debugText = messages
            .map { "[\($0.role.uppercased())]\n\($0.content)" }
            .joined(separator: "\n\n")

        return (messages, debugText)
    }

    public func validateAgentResponse(
        _ response: String,
        imageDescription: String?,
        userQuestion: String
    ) -> AgentResponseValidation {
        var text = sanitizeModelOutput(response)
        text = stripRoleLabels(from: text)
        text = removeRepeatedLines(from: text)

        guard !text.isEmpty else {
            return AgentResponseValidation(
                text: fallbackResponse(imageDescription: imageDescription),
                shouldRegenerate: true,
                reason: "Empty model response."
            )
        }

        if containsNonsense(text) {
            return AgentResponseValidation(
                text: fallbackResponse(imageDescription: imageDescription),
                shouldRegenerate: true,
                reason: "Response contained repeated or nonsensical text."
            )
        }

        let hasImageQuestion = imageDescription != nil || userQuestion.localizedCaseInsensitiveContains("image") || userQuestion.localizedCaseInsensitiveContains("photo") || userQuestion.localizedCaseInsensitiveContains("picture")
        if hasImageQuestion, isGenericImageDescription(imageDescription) {
            return AgentResponseValidation(
                text: "I can’t read enough from this photo to answer confidently. Please send a clearer, closer photo with the important label, object, or damage in frame.",
                shouldRegenerate: false,
                reason: "Image description was empty or generic."
            )
        }

        if imageDescription == nil && claimsVisualEvidence(text) {
            return AgentResponseValidation(
                text: "I don’t have a usable image for this turn, so I can’t verify what it shows. Send the photo again or describe what you want me to inspect.",
                shouldRegenerate: false,
                reason: "Response claimed visual evidence without image context."
            )
        }

        return AgentResponseValidation(text: text)
    }

    public func sanitizeStreamingToken(_ piece: String) -> String {
        var cleaned = piece
        for token in Self.modelSpecialTokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        return cleaned
    }

    public func sanitizeModelOutput(_ text: String) -> String {
        var cleaned = text
        for token in Self.modelSpecialTokens {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func build(
        personalityPrompt: String,
        memoryFacts: [String],
        historyMessages: [ChatMessage],
        historySummaryNote: String?,
        currentUtterance: String,
        visualContext: VisualContext? = nil
    ) -> (messages: [ChatMessage], debugText: String) {
        let memory = RelevantMemoryContext(userFacts: memoryFacts)
        let recentConversation = summarizeConversation(historyMessages: historyMessages, summaryNote: historySummaryNote)
        return buildAgentPrompt(
            AgentPromptInput(
                userQuestion: currentUtterance,
                imageDescription: visualContext?.caption,
                relevantMemory: memory,
                recentConversation: recentConversation
            ),
            personalityPrompt: personalityPrompt
        )
    }

    private static let modelSpecialTokens = [
        "<|end|>",
        "<|endoftext|>",
        "<|assistant|>",
        "<|user|>",
        "<|system|>",
    ]

    public func summarizeConversation(historyMessages: [ChatMessage], summaryNote: String?) -> String? {
        var lines = historyMessages.suffix(6).map { message in
            let role = message.role == "assistant" ? "Assistant" : "User"
            return "\(role): \(truncate(message.content, limit: 180))"
        }

        if let summaryNote, !summaryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.insert(summaryNote, at: 0)
        }

        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    public func isGenericImageDescription(_ description: String?) -> Bool {
        guard let cleaned = cleanBlock(description) else { return true }
        let lower = cleaned.lowercased()
        if cleaned.count < 40 { return true }
        let genericPhrases = [
            "unable to analyze",
            "no image provided",
            "an image",
            "a photo",
            "could not determine",
            "not enough visual detail"
        ]
        return genericPhrases.contains { lower == $0 || lower.hasPrefix($0 + ".") }
    }

    private func cleanBlock(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func truncate(_ value: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func stripRoleLabels(from response: String) -> String {
        var lines = response.components(separatedBy: .newlines)
        while let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              ["assistant:", "assistant", "system:", "system", "user:", "user", "answer:"].contains(first) {
            lines.removeFirst()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeRepeatedLines(from response: String) -> String {
        var output: [String] = []
        var previous = ""
        var repeatCount = 0

        for line in response.components(separatedBy: .newlines) {
            let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized == previous, !normalized.isEmpty {
                repeatCount += 1
                if repeatCount > 1 { continue }
            } else {
                repeatCount = 0
                previous = normalized
            }
            output.append(line)
        }

        return output.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsNonsense(_ response: String) -> Bool {
        let words = response.split { $0.isWhitespace || $0.isNewline }.map(String.init)
        guard words.count >= 12 else { return false }

        let uniqueRatio = Double(Set(words.map { $0.lowercased() }).count) / Double(words.count)
        if uniqueRatio < 0.28 { return true }

        let repeatedTriples = Dictionary(grouping: words.indices.dropLast(2).map { index in
            words[index..<(index + 3)].joined(separator: " ").lowercased()
        }, by: { $0 })
        return repeatedTriples.values.contains { $0.count >= 4 }
    }

    private func claimsVisualEvidence(_ response: String) -> Bool {
        let lower = response.lowercased()
        return lower.contains("i can see") || lower.contains("i see") || lower.contains("in the image") || lower.contains("in the photo") || lower.contains("the picture shows")
    }

    private func fallbackResponse(imageDescription: String?) -> String {
        if isGenericImageDescription(imageDescription) {
            return "I can’t answer from the current photo with confidence. Please send a clearer image or describe the key detail you want checked."
        }
        return "I’m not confident in that answer. Based on the available context, the safest next step is to verify the key detail and try again."
    }
}
