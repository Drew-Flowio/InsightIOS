import CryptoKit
import Foundation
import InsightStorage

public enum UserDataFileKind: String, Sendable, Equatable, CaseIterable {
    case csv
    case json
    case text
    case markdown

    public var customerLabel: String {
        switch self {
        case .csv: "CSV"
        case .json: "JSON"
        case .text: "Text"
        case .markdown: "Markdown"
        }
    }
}

public struct UserDataImportPreview: Sendable, Equatable {
    public let fileKind: UserDataFileKind
    public let recordCount: Int
    public let geographicRecordCount: Int
    public let suggestedTitle: String
    public let sourceFilename: String

    public init(
        fileKind: UserDataFileKind,
        recordCount: Int,
        geographicRecordCount: Int,
        suggestedTitle: String,
        sourceFilename: String
    ) {
        self.fileKind = fileKind
        self.recordCount = recordCount
        self.geographicRecordCount = geographicRecordCount
        self.suggestedTitle = suggestedTitle
        self.sourceFilename = sourceFilename
    }
}

public enum UserDataImporter {
    public enum Error: Swift.Error, Equatable {
        case unreadableFile
        case unsupportedFormat
        case noRecords
    }

    public static func isOGPackJSON(_ data: Data) -> Bool {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            object["formatVersion"] as? Int == 1,
            object["volume"] is [String: Any],
            object["records"] is [Any]
        else {
            return false
        }
        return true
    }

    public static func detectFileKind(filename: String, data: Data) -> UserDataFileKind? {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "csv":
            return .csv
        case "json":
            return isOGPackJSON(data) ? nil : .json
        case "md", "markdown":
            return .markdown
        case "txt", "text":
            return .text
        default:
            break
        }

        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        if text.contains(",") && text.contains("\n") && text.split(separator: "\n").count >= 2 {
            return .csv
        }
        if (try? JSONSerialization.jsonObject(with: data)) != nil, !isOGPackJSON(data) {
            return .json
        }
        if text.hasPrefix("#") || text.contains("\n## ") {
            return .markdown
        }
        return .text
    }

    public static func preview(data: Data, filename: String) throws -> UserDataImportPreview {
        guard let kind = detectFileKind(filename: filename, data: data) else {
            throw Error.unsupportedFormat
        }

        let volume = try buildVolume(data: data, filename: filename, title: suggestedTitle(from: filename), kind: kind)
        let geographicCount = volume.records.filter { record in
            GeographicRecordParser.parse(
                record: record,
                volumeID: volume.id,
                volumeTitle: volume.title
            ) != nil
        }.count

        return UserDataImportPreview(
            fileKind: kind,
            recordCount: volume.records.count,
            geographicRecordCount: geographicCount,
            suggestedTitle: suggestedTitle(from: filename),
            sourceFilename: filename
        )
    }

    public static func install(
        data: Data,
        filename: String,
        title: String,
        into repository: Repository,
        importsDirectory: URL
    ) -> MindImportOutcome {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return .failed(message: "Enter a name for this Mind before importing.")
        }

        let volume: KnowledgeVolume
        do {
            guard let kind = detectFileKind(filename: filename, data: data) else {
                return .failed(message: "This file type is not supported for import.")
            }
            volume = try buildVolume(data: data, filename: filename, title: trimmedTitle, kind: kind)
        } catch Error.noRecords {
            return .failed(message: "No usable records were found in this file.")
        } catch Error.unreadableFile {
            return .failed(message: "Could not read the selected file.")
        } catch Error.unsupportedFormat {
            return .failed(message: "This file type is not supported for import.")
        } catch {
            return .failed(message: "Could not import this file.")
        }

        if repository.knowledgeVolumeExists(id: volume.id) {
            return .duplicate(title: volume.title)
        }

        do {
            try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
            let preservedName = preservedFilename(for: volume.id, originalFilename: filename)
            let destination = importsDirectory.appendingPathComponent(preservedName)
            try data.write(to: destination, options: .atomic)
        } catch {
            return .failed(message: "Could not save the original file on this device.")
        }

        MindBootstrap.install(
            volume: volume,
            sourceLabel: sourceLabel(for: volume, filename: filename),
            enabled: true,
            in: repository
        )
        return .imported(title: volume.title)
    }

    static func buildVolume(
        data: Data,
        filename: String,
        title: String,
        kind: UserDataFileKind
    ) throws -> KnowledgeVolume {
        let records: [KnowledgeRecord]
        switch kind {
        case .csv:
            records = try recordsFromCSV(data: data, filename: filename)
        case .json:
            records = try recordsFromJSON(data: data, filename: filename)
        case .text, .markdown:
            records = try recordsFromText(data: data, filename: filename, title: title, markdown: kind == .markdown)
        }

        guard !records.isEmpty else { throw Error.noRecords }

        let id = volumeID(for: filename, data: data, title: title)
        return KnowledgeVolume(
            id: id,
            title: title,
            version: "1.0",
            summary: summary(for: kind, recordCount: records.count, filename: filename),
            tags: ["user-import", kind.rawValue, "private"],
            records: records
        )
    }

    private static func recordsFromCSV(data: Data, filename: String) throws -> [KnowledgeRecord] {
        guard let text = String(data: data, encoding: .utf8) else { throw Error.unreadableFile }
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { throw Error.noRecords }

        let delimiter = detectDelimiter(in: lines[0])
        let headers = parseDelimitedRow(lines[0], delimiter: delimiter).map { $0.lowercased() }
        let mapping = FieldMapping(headers: headers)

        return lines.dropFirst().enumerated().compactMap { index, line -> KnowledgeRecord? in
            let values = parseDelimitedRow(line, delimiter: delimiter)
            guard values.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                return nil
            }
            let rowMapping = mapping.rowValues(headers: headers, values: values)
            return makeRecord(from: rowMapping, index: index, filename: filename)
        }
    }

    private static func recordsFromJSON(data: Data, filename: String) throws -> [KnowledgeRecord] {
        let object = try JSONSerialization.jsonObject(with: data)
        let rows: [[String: Any]]
        if let array = object as? [[String: Any]] {
            rows = array
        } else if
            let dictionary = object as? [String: Any],
            let array = dictionary["records"] as? [[String: Any]] ?? dictionary["items"] as? [[String: Any]]
        {
            rows = array
        } else if let dictionary = object as? [String: Any] {
            rows = [dictionary]
        } else {
            throw Error.noRecords
        }

        return rows.enumerated().compactMap { index, row -> KnowledgeRecord? in
            let mapping = FieldMapping(json: row)
            return makeRecord(from: mapping, index: index, filename: filename)
        }
    }

    private static func recordsFromText(data: Data, filename: String, title: String, markdown: Bool) throws -> [KnowledgeRecord] {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw Error.unreadableFile
        }

        let sections: [(title: String, content: String)]
        if markdown {
            sections = markdownSections(from: text)
        } else {
            sections = textSections(from: text, fallbackTitle: title)
        }

        if sections.isEmpty {
            throw Error.noRecords
        }

        return sections.enumerated().map { index, section in
            KnowledgeRecord(
                id: recordID(for: section.title, index: index),
                title: section.title,
                content: section.content,
                tags: baseTags(filename: filename)
            )
        }
    }

    private static func makeRecord(
        from mapping: FieldMapping,
        index: Int,
        filename: String
    ) -> KnowledgeRecord? {
        let title = mapping.title ?? "Record \(index + 1)"
        let content = mapping.content ?? mapping.title ?? ""
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var tags = baseTags(filename: filename)
        tags.append(contentsOf: mapping.tags)
        tags.append(contentsOf: geographicTags(from: mapping))

        return KnowledgeRecord(
            id: recordID(for: title, index: index),
            title: title,
            content: content,
            tags: Array(Set(tags))
        )
    }

    private static func geographicTags(from mapping: FieldMapping) -> [String] {
        guard let latitude = mapping.latitude, let longitude = mapping.longitude else { return [] }
        var tags = [String(format: "geo:%.4f,%.4f", latitude, longitude)]
        let kind = mapping.geoKind ?? "place"
        tags.append("geo-type:\(kind)")
        if let name = mapping.geoName, !name.isEmpty {
            tags.append("geo-name:\(name)")
        } else if let title = mapping.title, !title.isEmpty {
            tags.append("geo-name:\(title)")
        }
        return tags
    }

    private static func baseTags(filename: String) -> [String] {
        ["imported", "source-file:\((filename as NSString).lastPathComponent)"]
    }

    private static func markdownSections(from text: String) -> [(title: String, content: String)] {
        let normalized = text.hasPrefix("#") ? text : "# Imported Notes\n\n" + text
        let chunks = normalized.components(separatedBy: "\n## ")
        return chunks.enumerated().compactMap { index, chunk in
            let lines = chunk.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            guard let firstLine = lines.first else { return nil }
            let rawTitle = firstLine.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            let title = rawTitle.isEmpty ? "Section \(index + 1)" : rawTitle
            let content = lines.count > 1 ? String(lines[1]).trimmingCharacters(in: .whitespacesAndNewlines) : title
            guard !content.isEmpty else { return nil }
            return (title, content)
        }
    }

    private static func textSections(from text: String, fallbackTitle: String) -> [(title: String, content: String)] {
        let chunks = text.components(separatedBy: "\n\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if chunks.count <= 1 {
            return [(fallbackTitle, text)]
        }

        return chunks.enumerated().map { index, chunk in
            let lines = chunk.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            if lines.count == 2, lines[0].count <= 80 {
                return (String(lines[0]), String(lines[1]))
            }
            return ("Entry \(index + 1)", chunk)
        }
    }

    private static func detectDelimiter(in header: String) -> Character {
        let candidates: [Character] = [",", ";", "\t"]
        return candidates.max { lhs, rhs in
            header.filter { $0 == lhs }.count < header.filter { $0 == rhs }.count
        } ?? ","
    }

    private static func parseDelimitedRow(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for character in line {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == delimiter, !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
        }

        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields
    }

    private static func recordID(for title: String, index: Int) -> String {
        let slug = slugify(title)
        return "import.\(slug).\(index + 1)"
    }

    private static func suggestedTitle(from filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Imported Data" }
        return trimmed
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }

    private static func volumeID(for filename: String, data: Data, title: String) -> String {
        let slug = slugify(title)
        let hash = SHA256.hash(data: data)
            .prefix(4)
            .map { String(format: "%02x", $0) }
            .joined()
        return "mind.user.\(slug).\(hash)"
    }

    private static func slugify(_ title: String) -> String {
        let lowered = title.lowercased()
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let slug = parts.joined(separator: "-")
        if slug.isEmpty { return "import" }
        return String(slug.prefix(40))
    }

    private static func summary(for kind: UserDataFileKind, recordCount: Int, filename: String) -> String {
        "Imported \(kind.customerLabel) · \(recordCount) record\(recordCount == 1 ? "" : "s") · \((filename as NSString).lastPathComponent)"
    }

    private static func sourceLabel(for volume: KnowledgeVolume, filename: String) -> String {
        "imported.user.\((filename as NSString).pathExtension.lowercased())"
    }

    private static func preservedFilename(for volumeID: String, originalFilename: String) -> String {
        let base = (originalFilename as NSString).lastPathComponent
        return "\(volumeID)-\(base)"
    }
}

private struct FieldMapping {
    var title: String?
    var content: String?
    var tags: [String] = []
    var latitude: Double?
    var longitude: Double?
    var geoName: String?
    var geoKind: String?

    init(headers: [String]) {}

    init(json: [String: Any]) {
        let normalized = json.reduce(into: [String: Any]()) { result, entry in
            result[entry.key.lowercased()] = entry.value
        }
        title = stringValue(normalized, keys: ["title", "name", "label", "item", "subject", "heading"])
        content = stringValue(normalized, keys: ["content", "description", "notes", "note", "body", "text", "details", "summary"])
        geoName = stringValue(normalized, keys: ["geo-name", "place", "location", "site"])
        geoKind = stringValue(normalized, keys: ["geo-type", "kind", "type"])?.lowercased()
        latitude = doubleValue(normalized, keys: ["latitude", "lat"])
        longitude = doubleValue(normalized, keys: ["longitude", "lon", "lng", "long"])
        if let tagsValue = normalized["tags"] {
            tags = parseTags(tagsValue)
        }
    }

    func rowValues(headers: [String], values: [String]) -> FieldMapping {
        var mapping = FieldMapping(headers: headers)
        for (header, value) in zip(headers, values) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            switch header {
            case "title", "name", "label", "item", "subject", "heading":
                mapping.title = trimmed
            case "content", "description", "notes", "note", "body", "text", "details", "summary":
                mapping.content = trimmed
            case "geo-name", "place", "location", "site":
                mapping.geoName = trimmed
            case "geo-type", "kind", "type":
                mapping.geoKind = trimmed.lowercased()
            case "latitude", "lat":
                mapping.latitude = Double(trimmed)
            case "longitude", "lon", "lng", "long":
                mapping.longitude = Double(trimmed)
            case "tags":
                mapping.tags = trimmed
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            default:
                if mapping.content == nil {
                    mapping.content = "\(header): \(trimmed)"
                } else {
                    mapping.content? += "\n\(header): \(trimmed)"
                }
            }
        }
        return mapping
    }

    private func stringValue(_ json: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = json[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private func doubleValue(_ json: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = json[key] as? Double { return value }
            if let value = json[key] as? Int { return Double(value) }
            if let value = json[key] as? String { return Double(value) }
        }
        return nil
    }

    private func parseTags(_ value: Any) -> [String] {
        if let array = value as? [String] {
            return array.filter { !$0.isEmpty }
        }
        if let text = value as? String {
            return text
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}
