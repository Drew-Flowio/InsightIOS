import CryptoKit
import Foundation
import PDFKit

public enum PDFManualParser {
    public enum Error: Swift.Error, Equatable {
        case unreadablePDF
        case noExtractableText
    }

    public static func extractPages(from data: Data) throws -> [(pageNumber: Int, text: String)] {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw Error.unreadablePDF
        }

        var pages: [(pageNumber: Int, text: String)] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            pages.append((pageNumber: index + 1, text: text))
        }

        guard pages.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw Error.noExtractableText
        }

        return pages
    }

    public static func buildVolume(
        pdfData: Data,
        suggestedFilename: String
    ) throws -> KnowledgeVolume {
        let pages = try extractPages(from: pdfData)
        let records = PDFManualRecordBuilder.records(from: pages)
        guard !records.isEmpty else {
            throw Error.noExtractableText
        }

        let title = humanTitle(from: suggestedFilename)
        let id = volumeID(for: suggestedFilename, pdfData: pdfData)

        return KnowledgeVolume(
            id: id,
            title: title,
            version: "1.0",
            summary: "Private manual · \(records.count) page\(records.count == 1 ? "" : "s") with readable text",
            tags: ["manual", "private", "pdf"],
            records: records
        )
    }

    public static func volumeID(for filename: String, pdfData: Data) -> String {
        let slug = slugify(humanTitle(from: filename))
        let hash = SHA256.hash(data: pdfData)
            .prefix(4)
            .map { String(format: "%02x", $0) }
            .joined()
        return "mind.manual.\(slug).\(hash)"
    }

    static func humanTitle(from filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Imported Manual" }
        return trimmed
    }

    static func slugify(_ title: String) -> String {
        let lowered = title.lowercased()
        let parts = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let slug = parts.joined(separator: "-")
        if slug.isEmpty { return "manual" }
        return String(slug.prefix(40))
    }

    public static func pageCount(at pdfURL: URL) -> Int? {
        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else { return nil }
        return document.pageCount
    }
}
