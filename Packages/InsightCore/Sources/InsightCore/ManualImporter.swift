import Foundation
import InsightStorage

public enum ManualImporter {
    public static func importPDF(
        data: Data,
        suggestedFilename: String,
        into repository: Repository,
        manualsDirectory: URL
    ) -> MindImportOutcome {
        let volume: KnowledgeVolume
        do {
            volume = try PDFManualParser.buildVolume(
                pdfData: data,
                suggestedFilename: suggestedFilename
            )
        } catch PDFManualParser.Error.unreadablePDF {
            return .failed(message: "Could not read this PDF file.")
        } catch PDFManualParser.Error.noExtractableText {
            return .failed(message: "This PDF does not contain readable text. Scanned image-only PDFs are not supported yet.")
        } catch {
            return .failed(message: "Could not import this manual.")
        }

        if repository.knowledgeVolumeExists(id: volume.id) {
            return .duplicate(title: volume.title)
        }

        do {
            try FileManager.default.createDirectory(
                at: manualsDirectory,
                withIntermediateDirectories: true
            )
            let destination = manualsDirectory.appendingPathComponent("\(volume.id).pdf")
            try data.write(to: destination, options: .atomic)
        } catch {
            return .failed(message: "Could not save the original PDF on this device.")
        }

        MindBootstrap.install(
            volume: volume,
            sourceLabel: "imported.pdf",
            enabled: true,
            in: repository
        )
        return .imported(title: volume.title)
    }
}
