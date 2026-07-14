import Foundation

public struct PromptImprovementInput: Sendable, Equatable {
    public let roughQuestion: String
    public let imageDescription: String?
    public let workspaceDescription: String?
    public let locationDescription: String?
    public let enabledMindTitles: [String]
    public let userProfile: UserProfileContext
    public let relevantMemory: RelevantMemoryContext
    public let retrievedKnowledge: RetrievedKnowledgeContext

    public init(
        roughQuestion: String,
        imageDescription: String? = nil,
        workspaceDescription: String? = nil,
        locationDescription: String? = nil,
        enabledMindTitles: [String] = [],
        userProfile: UserProfileContext = UserProfileContext(),
        relevantMemory: RelevantMemoryContext = RelevantMemoryContext(),
        retrievedKnowledge: RetrievedKnowledgeContext = RetrievedKnowledgeContext()
    ) {
        self.roughQuestion = roughQuestion
        self.imageDescription = imageDescription
        self.workspaceDescription = workspaceDescription
        self.locationDescription = locationDescription
        self.enabledMindTitles = enabledMindTitles
        self.userProfile = userProfile
        self.relevantMemory = relevantMemory
        self.retrievedKnowledge = retrievedKnowledge
    }
}

public struct PromptBuilderDraftResult: Sendable, Equatable {
    public let improvedText: String
    public let originalText: String
    public let builderEnabledAfter: Bool

    public init(improvedText: String, originalText: String, builderEnabledAfter: Bool) {
        self.improvedText = improvedText
        self.originalText = originalText
        self.builderEnabledAfter = builderEnabledAfter
    }
}

public enum PromptBuilderSendDecision: Equatable, Sendable {
    case improveQuestion(roughText: String)
    case sendNormally(text: String)
}

public enum PromptBuilderSendRouter {
    public static func decision(text: String, builderEnabled: Bool) -> PromptBuilderSendDecision? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if builderEnabled {
            return .improveQuestion(roughText: trimmed)
        }
        return .sendNormally(text: trimmed)
    }

    public static func applyDraft(
        improved: String,
        original: String,
        builderEnabled: inout Bool
    ) -> PromptBuilderDraftResult {
        let result = PromptBuilderDraftResult(
            improvedText: improved,
            originalText: original,
            builderEnabledAfter: false
        )
        builderEnabled = false
        return result
    }
}

public extension PromptBuilder {
    func buildPromptImprovementMessages(_ input: PromptImprovementInput) -> [ChatMessage] {
        let imageBlock = cleanImprovementBlock(input.imageDescription) ?? "No photo attached."
        let workspaceBlock = cleanImprovementBlock(input.workspaceDescription) ?? "Not in visual workspace."
        let locationBlock = cleanImprovementBlock(input.locationDescription) ?? "No location attached."
        let profileBlock = input.userProfile.promptBlock()
        let memoryBlock = input.relevantMemory.promptBlock()
        let knowledgeBlock = input.retrievedKnowledge.promptBlock()
        let mindsBlock = input.enabledMindTitles.isEmpty
            ? "No enabled Minds."
            : input.enabledMindTitles.map { "- \($0)" }.joined(separator: "\n")

        let systemContent = """
        You rewrite rough user questions into clearer, more useful prompts for a local assistant.
        Do NOT answer the question. Output ONLY the improved question text.

        Rules:
        - Keep the improved prompt concise (usually 1-3 sentences).
        - Clarify the task, relevant symptoms or constraints, desired answer format, and source expectations when helpful.
        - Use the context blocks below only as hints about what the user may be referring to.
        - Do not invent facts, manual contents, or source details beyond what appears in context.
        - Do not claim a source contains information that is not shown in RETRIEVED SOURCE EXCERPTS.
        - Do not include labels such as "Improved question:" or quotation marks around the whole prompt.
        - Preserve the user's intent; do not change the topic.
        """

        let userContent = """
        ROUGH QUESTION:
        \(input.roughQuestion.trimmingCharacters(in: .whitespacesAndNewlines))

        PHOTO / OCR / VISUAL CONTEXT:
        \(imageBlock)

        VISUAL WORKSPACE:
        \(workspaceBlock)

        LOCATION CONTEXT:
        \(locationBlock)

        USER PROFILE:
        \(profileBlock)

        RELEVANT USER MEMORY:
        \(memoryBlock)

        ENABLED MINDS (titles only):
        \(mindsBlock)

        RETRIEVED SOURCE EXCERPTS (use only these; do not extrapolate):
        \(knowledgeBlock)
        """

        return [
            ChatMessage(role: "system", content: systemContent),
            ChatMessage(role: "user", content: userContent),
        ]
    }

    private func cleanImprovementBlock(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
