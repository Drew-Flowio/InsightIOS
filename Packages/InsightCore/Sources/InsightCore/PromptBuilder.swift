import Foundation

/// Assembles the exact message list sent to the LLM for a single turn.
public struct PromptBuilder: Sendable {
    public init() {}

    public func build(
        personalityPrompt: String,
        memoryFacts: [String],
        historyMessages: [ChatMessage],
        historySummaryNote: String?,
        currentUtterance: String,
        visualContext: VisualContext? = nil
    ) -> (messages: [ChatMessage], debugText: String) {
        var systemContent = personalityPrompt.trimmingCharacters(in: .whitespacesAndNewlines)

        if !memoryFacts.isEmpty {
            let factsBlock = memoryFacts.map { "- \($0)" }.joined(separator: "\n")
            systemContent += "\n\nThings you know about the user (long-term memory):\n\(factsBlock)"
        }

        if let visualContext {
            systemContent += "\n\n\(visualContext.promptBlock())"
        }

        if let historySummaryNote {
            systemContent += "\n\n\(historySummaryNote)"
        }

        var messages: [ChatMessage] = [ChatMessage(role: "system", content: systemContent)]
        messages.append(contentsOf: historyMessages)
        messages.append(ChatMessage(role: "user", content: currentUtterance))

        let debugText = messages
            .map { "[\($0.role.uppercased())]\n\($0.content)" }
            .joined(separator: "\n\n")

        return (messages, debugText)
    }
}
