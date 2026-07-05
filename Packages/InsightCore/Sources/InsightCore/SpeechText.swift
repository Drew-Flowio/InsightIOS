import Foundation

/// Prepare assistant text for text-to-speech playback.
public enum SpeechText {
    public static let spokenHandoff = "I'll put the longer details in text for you."

    public static func prepareForSpeech(_ text: String) -> String {
        let spoken = truncateAtHandoff(text)
        let stripped = stripMarkup(spoken)
        return stripped
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func truncateAtHandoff(_ text: String) -> String {
        let lower = text.lowercased()
        let marker = spokenHandoff.lowercased()
        guard let range = lower.range(of: marker) else {
            return text
        }

        let endIndex = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.upperBound))
        return String(text[..<endIndex])
    }

    private static func stripMarkup(_ text: String) -> String {
        var result = text

        result = replaceRegex(
            #"```[\s\S]*?```"#,
            in: result,
            options: [.dotMatchesLineSeparators],
            with: "There's a code snippet in the text."
        )
        result = replaceRegex(#"\[[^\]]+\]|<[^>]+>"#, in: result, with: "")
        result = replaceRegex(#"^#{1,6}\s+"#, in: result, options: [.anchorsMatchLines], with: "")
        result = replaceRegex(#"\*\*([^*]+)\*\*|\*([^*]+)\*|__([^_]+)__|_([^_]+)_"#, in: result) { match in
            match.dropFirst().compactMap { $0 }.first ?? ""
        }
        result = replaceRegex(#"`([^`]+)`"#, in: result) { match in
            match.dropFirst().first ?? ""
        }
        result = replaceRegex(#"^\s*(?:[-*•]|\d+\.)\s+"#, in: result, options: [.anchorsMatchLines], with: "")
        result = replaceRegex(#"(?<=\s)#(\w+)"#, in: result) { match in
            match.dropFirst().first ?? ""
        }
        result = replaceRegex(
            #"[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2702}-\u{27B0}\u{24C2}-\u{1F251}]+"#,
            in: result,
            with: ""
        )

        return result.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "#", with: "")
    }

    private static func replaceRegex(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        with replacement: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private static func replaceRegex(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        transform: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return text
        }

        var result = text
        for match in matches.reversed() {
            var groups: [String] = []
            for index in 0..<match.numberOfRanges {
                let range = match.range(at: index)
                groups.append(range.location != NSNotFound ? nsText.substring(with: range) : "")
            }
            let replacement = transform(groups)
            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: replacement)
            }
        }
        return result
    }
}
