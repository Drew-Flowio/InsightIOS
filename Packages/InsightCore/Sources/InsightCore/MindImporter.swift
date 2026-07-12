import Foundation
import InsightStorage

public enum MindImporter {
    public static func importOGPack(
        data: Data,
        into repository: Repository,
        sourceLabel: String = "imported.ogpack"
    ) -> MindImportOutcome {
        let volume: KnowledgeVolume
        do {
            volume = try OGPackParser.parse(data: data)
        } catch let error as OGPackParser.Error {
            return .failed(message: message(for: error))
        } catch {
            return .failed(message: "Could not read this Mind file.")
        }

        if repository.knowledgeVolumeExists(id: volume.id) {
            return .duplicate(title: volume.title)
        }

        MindBootstrap.install(
            volume: volume,
            sourceLabel: sourceLabel,
            enabled: true,
            in: repository
        )
        return .imported(title: volume.title)
    }

    private static func message(for error: OGPackParser.Error) -> String {
        switch error {
        case .unsupportedFormatVersion(let version):
            "Unsupported Mind format version \(version)."
        case .missingVolume:
            "This Mind file is missing volume information."
        case .emptyRecords:
            "This Mind file does not contain any knowledge records."
        }
    }
}
