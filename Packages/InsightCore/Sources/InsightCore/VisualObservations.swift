import Foundation

public enum VisualConfidence: String, Sendable, Equatable, Codable {
    case low
    case medium
    case high
}

public enum VisionAnalysisSource: String, Sendable, Equatable, Codable {
    case ocrOnly
    case ocrAndVlm
    case vlmUnavailable
    case vlmFailed
}

/// Structured output from the on-device VLM prototype (SmolVLM-class).
public struct VisualObservations: Sendable, Equatable, Codable {
    public let visibleObjects: [String]
    public let readableLabels: [String]
    public let possibleProblems: [String]
    public let confidence: VisualConfidence
    public let needsAnotherAngle: Bool
    public let summary: String

    public init(
        visibleObjects: [String] = [],
        readableLabels: [String] = [],
        possibleProblems: [String] = [],
        confidence: VisualConfidence = .low,
        needsAnotherAngle: Bool = true,
        summary: String = ""
    ) {
        self.visibleObjects = visibleObjects
        self.readableLabels = readableLabels
        self.possibleProblems = possibleProblems
        self.confidence = confidence
        self.needsAnotherAngle = needsAnotherAngle
        self.summary = summary
    }

    public var isEmpty: Bool {
        visibleObjects.isEmpty &&
            readableLabels.isEmpty &&
            possibleProblems.isEmpty &&
            summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct VisualObservationsParser: Sendable {
    public init() {}

    public func parse(_ raw: String) -> VisualObservations? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let jsonCandidate = extractJSONObject(from: trimmed) ?? trimmed
        guard let data = jsonCandidate.data(using: .utf8) else { return nil }

        if let decoded = try? JSONDecoder().decode(VisualObservations.self, from: data) {
            return decoded
        }

        if let generic = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return VisualObservations(
                visibleObjects: stringArray(generic["visibleObjects"]),
                readableLabels: stringArray(generic["readableLabels"]),
                possibleProblems: stringArray(generic["possibleProblems"]),
                confidence: confidence(from: generic["confidence"]),
                needsAnotherAngle: boolValue(generic["needsAnotherAngle"]) ?? true,
                summary: stringValue(generic["summary"]) ?? ""
            )
        }

        return nil
    }

    public func encodeJSON(_ observations: VisualObservations) -> String? {
        guard let data = try? JSONEncoder().encode(observations) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }

    private func stringArray(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { item in
            let text = stringValue(item) ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        if let text = value as? String {
            switch text.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    private func confidence(from value: Any?) -> VisualConfidence {
        guard let text = stringValue(value)?.lowercased() else { return .low }
        switch text {
        case "high": return .high
        case "medium", "med": return .medium
        default: return .low
        }
    }
}
