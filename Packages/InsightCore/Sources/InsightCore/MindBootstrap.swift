import Foundation
import InsightStorage

public enum MindBootstrap {
    public static func seedBundledMindsIfNeeded(in repository: Repository) {
        for loader in BundledMinds.bundledMindLoaders() {
            guard let volume = try? loader() else { continue }
            if repository.knowledgeVolumeExists(id: volume.id) {
                upsertMissingRecords(from: volume, in: repository)
            } else {
                install(volume: volume, sourceLabel: "bundled.ogpack", enabled: true, in: repository)
            }
        }
    }

    public static func upsertMissingRecords(from volume: KnowledgeVolume, in repository: Repository) {
        for record in volume.records where !repository.knowledgeRecordExists(volumeID: volume.id, recordID: record.id) {
            repository.insertKnowledgeRecord(
                volumeID: volume.id,
                id: record.id,
                title: record.title,
                content: record.content,
                tags: record.tags
            )
        }
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
            version: volume.version,
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
                version: volumeRecord.resolvedVersion,
                summary: volumeRecord.summary,
                tags: volumeRecord.tags,
                records: records.map {
                    KnowledgeRecord(id: $0.id, title: $0.title, content: $0.content, tags: $0.tags)
                }
            )
        }
    }

    public static func enabledGeographicRecords(from repository: Repository) -> [GeographicRecord] {
        repository.enabledKnowledgeVolumesWithRecords().flatMap { volumeRecord, records in
            let volume = KnowledgeVolume(
                id: volumeRecord.id,
                title: volumeRecord.title,
                version: volumeRecord.resolvedVersion,
                summary: volumeRecord.summary,
                tags: volumeRecord.tags,
                records: records.map {
                    KnowledgeRecord(id: $0.id, title: $0.title, content: $0.content, tags: $0.tags)
                }
            )
            return GeographicRecordParser.records(from: volume, sourceLabel: volumeRecord.sourceLabel)
        }
    }
}
