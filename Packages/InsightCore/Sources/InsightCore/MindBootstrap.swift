import Foundation
import InsightStorage

public enum MindBootstrap {
    public static func seedBundledMindsIfNeeded(in repository: Repository) {
        guard !repository.knowledgeVolumeExists(id: "mind.florida-coastal-demo") else {
            return
        }

        guard let volume = try? BundledMinds.floridaCoastalDemoVolume() else {
            return
        }

        install(volume: volume, sourceLabel: "bundled.ogpack", enabled: true, in: repository)
    }

    public static func install(
        volume: KnowledgeVolume,
        sourceLabel: String,
        enabled: Bool,
        in repository: Repository
    ) {
        repository.installKnowledgeVolume(
            id: volume.id,
            title: volume.title,
            summary: volume.summary,
            tags: volume.tags,
            sourceLabel: sourceLabel,
            records: volume.records.map { ($0.id, $0.title, $0.content, $0.tags) },
            enabled: enabled
        )
    }

    public static func enabledVolumes(from repository: Repository) -> [KnowledgeVolume] {
        repository.enabledKnowledgeVolumesWithRecords().map { volumeRecord, records in
            KnowledgeVolume(
                id: volumeRecord.id,
                title: volumeRecord.title,
                summary: volumeRecord.summary,
                tags: volumeRecord.tags,
                records: records.map {
                    KnowledgeRecord(id: $0.id, title: $0.title, content: $0.content, tags: $0.tags)
                }
            )
        }
    }
}
