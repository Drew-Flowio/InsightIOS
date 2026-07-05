import Foundation

public enum DefaultPrompts {
    public static let bundledSystemPromptResource = "system_prompt"

    public static func bundledSystemPrompt() -> String {
        guard
            let url = Bundle.module.url(forResource: bundledSystemPromptResource, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            preconditionFailure("Missing bundled system_prompt.txt")
        }
        return text
    }
}
