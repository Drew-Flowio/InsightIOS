import Foundation

/// Converts extracted PDF page text into knowledge records with page references.
public enum PDFManualRecordBuilder {
    public static func records(from pages: [(pageNumber: Int, text: String)]) -> [KnowledgeRecord] {
        pages.compactMap { page in
            let text = page.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 20 else { return nil }

            return KnowledgeRecord(
                id: "page.\(page.pageNumber)",
                title: "Page \(page.pageNumber)",
                content: text,
                tags: ["manual", "page:\(page.pageNumber)"]
            )
        }
    }
}
