import Foundation
import SQLite3

public final class Repository: @unchecked Sendable {
    private let connection: OpaquePointer

    public init(dbPath: String) throws {
        let pathURL = URL(fileURLWithPath: dbPath)
        try FileManager.default.createDirectory(
            at: pathURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        connection = try Database.open(at: dbPath)
    }

    init(connection: OpaquePointer) {
        self.connection = connection
    }

    public static func inMemory() throws -> Repository {
        Repository(connection: try Database.openInMemory())
    }

    deinit {
        sqlite3_close(connection)
    }

    // MARK: - Sessions

    @discardableResult
    public func createSession() -> SessionRecord {
        let session = SessionRecord(
            id: Self.newID(),
            startedAt: Self.now(),
            endedAt: nil,
            status: "active"
        )
        execute(
            "INSERT INTO sessions (id, started_at, ended_at, status) VALUES (?, ?, ?, ?)",
            bindings: [.text(session.id), .text(session.startedAt), .null, .text(session.status)]
        )
        return session
    }

    public func endSession(sessionID: String) {
        execute(
            "UPDATE sessions SET status = 'ended', ended_at = ? WHERE id = ?",
            bindings: [.text(Self.now()), .text(sessionID)]
        )
    }

    public func getLatestActiveSession() -> SessionRecord? {
        queryOne(
            "SELECT id, started_at, ended_at, status FROM sessions WHERE status = 'active' ORDER BY started_at DESC LIMIT 1",
            map: Self.mapSession
        )
    }

    public func listSessions(limit: Int = 50) -> [SessionRecord] {
        queryMany(
            "SELECT id, started_at, ended_at, status FROM sessions ORDER BY started_at DESC LIMIT ?",
            bindings: [.int(limit)],
            map: Self.mapSession
        )
    }

    // MARK: - Messages

    @discardableResult
    public func addMessage(
        sessionID: String,
        role: String,
        content: String,
        source: String = "text",
        imagePath: String? = nil,
        ocrText: String? = nil,
        visualObservationsJSON: String? = nil,
        locationJSON: String? = nil,
        promptVersionID: String? = nil,
        latencyMs: Int? = nil,
        cancelled: Bool = false
    ) -> MessageRecord {
        let message = MessageRecord(
            id: Self.newID(),
            sessionID: sessionID,
            timestamp: Self.now(),
            role: role,
            content: content,
            source: source,
            imagePath: imagePath,
            ocrText: ocrText,
            visualObservationsJSON: visualObservationsJSON,
            locationJSON: locationJSON,
            promptVersionID: promptVersionID,
            latencyMs: latencyMs,
            cancelled: cancelled
        )
        execute(
            """
            INSERT INTO messages
            (id, session_id, ts, role, content, source, image_path, ocr_text, visual_observations_json, location_json, prompt_version_id, latency_ms, cancelled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(message.id),
                .text(message.sessionID),
                .text(message.timestamp),
                .text(message.role),
                .text(message.content),
                .text(message.source),
                imagePath.map(SQLValue.text) ?? .null,
                ocrText.map(SQLValue.text) ?? .null,
                visualObservationsJSON.map(SQLValue.text) ?? .null,
                locationJSON.map(SQLValue.text) ?? .null,
                message.promptVersionID.map(SQLValue.text) ?? .null,
                message.latencyMs.map(SQLValue.int) ?? .null,
                .int(cancelled ? 1 : 0),
            ]
        )
        return message
    }

    public func getSessionMessages(sessionID: String, limit: Int = 500) -> [MessageRecord] {
        queryMany(
            """
            SELECT id, session_id, ts, role, content, source, image_path, ocr_text, visual_observations_json, location_json, prompt_version_id, latency_ms, cancelled
            FROM messages WHERE session_id = ? ORDER BY ts ASC LIMIT ?
            """,
            bindings: [.text(sessionID), .int(limit)],
            map: Self.mapMessage
        )
    }

    public func countSessionMessages(sessionID: String) -> Int {
        queryOne(
            "SELECT COUNT(*) AS c FROM messages WHERE session_id = ?",
            bindings: [.text(sessionID)],
            map: { statement in
                Int(sqlite3_column_int(statement, 0))
            }
        ) ?? 0
    }

    // MARK: - Prompt versions

    @discardableResult
    public func savePromptVersion(content: String, label: String? = nil) -> PromptVersionRecord {
        let version = PromptVersionRecord(
            id: Self.newID(),
            content: content,
            label: label,
            createdAt: Self.now(),
            isActive: true
        )
        execute("UPDATE prompt_versions SET is_active = 0")
        execute(
            "INSERT INTO prompt_versions (id, content, label, created_at, is_active) VALUES (?, ?, ?, ?, 1)",
            bindings: [
                .text(version.id),
                .text(version.content),
                version.label.map(SQLValue.text) ?? .null,
                .text(version.createdAt),
            ]
        )
        return version
    }

    public func getActivePromptVersion() -> PromptVersionRecord? {
        queryOne(
            """
            SELECT id, content, label, created_at, is_active
            FROM prompt_versions WHERE is_active = 1 ORDER BY created_at DESC LIMIT 1
            """,
            map: Self.mapPromptVersion
        )
    }

    public func activatePromptVersion(versionID: String) -> PromptVersionRecord? {
        execute("UPDATE prompt_versions SET is_active = 0")
        execute(
            "UPDATE prompt_versions SET is_active = 1 WHERE id = ?",
            bindings: [.text(versionID)]
        )
        return queryOne(
            """
            SELECT id, content, label, created_at, is_active
            FROM prompt_versions WHERE id = ?
            """,
            bindings: [.text(versionID)],
            map: Self.mapPromptVersion
        )
    }

    public func listPromptVersions(limit: Int = 50) -> [PromptVersionRecord] {
        queryMany(
            """
            SELECT id, content, label, created_at, is_active
            FROM prompt_versions ORDER BY created_at DESC LIMIT ?
            """,
            bindings: [.int(limit)],
            map: Self.mapPromptVersion
        )
    }

    // MARK: - Memory facts

    @discardableResult
    public func addMemoryFact(text: String) -> MemoryFactRecord {
        let fact = MemoryFactRecord(
            id: Self.newID(),
            text: text,
            createdAt: Self.now(),
            active: true
        )
        execute(
            "INSERT INTO memory_facts (id, text, created_at, active) VALUES (?, ?, ?, 1)",
            bindings: [.text(fact.id), .text(fact.text), .text(fact.createdAt)]
        )
        return fact
    }

    public func listMemoryFacts(activeOnly: Bool = true) -> [MemoryFactRecord] {
        if activeOnly {
            return queryMany(
                "SELECT id, text, created_at, active FROM memory_facts WHERE active = 1 ORDER BY created_at ASC",
                map: Self.mapMemoryFact
            )
        }
        return queryMany(
            "SELECT id, text, created_at, active FROM memory_facts ORDER BY created_at ASC",
            map: Self.mapMemoryFact
        )
    }

    public func removeMemoryFact(factID: String) {
        execute(
            "UPDATE memory_facts SET active = 0 WHERE id = ?",
            bindings: [.text(factID)]
        )
    }

    public func clearAllMemoryFacts() {
        execute("UPDATE memory_facts SET active = 0")
    }

    // MARK: - User profile

    public func getUserProfile() -> UserProfileRecord? {
        queryOne(
            """
            SELECT display_name, response_style, general_notes, updated_at
            FROM user_profile WHERE id = 'default' LIMIT 1
            """,
            map: Self.mapUserProfile
        )
    }

    @discardableResult
    public func upsertUserProfile(
        displayName: String?,
        responseStyle: String?,
        generalNotes: String?
    ) -> UserProfileRecord {
        let profile = UserProfileRecord(
            displayName: Self.normalizedOptional(displayName),
            responseStyle: Self.normalizedOptional(responseStyle),
            generalNotes: Self.normalizedOptional(generalNotes),
            updatedAt: Self.now()
        )

        execute("DELETE FROM user_profile WHERE id = 'default'")
        execute(
            """
            INSERT INTO user_profile (id, display_name, response_style, general_notes, updated_at)
            VALUES ('default', ?, ?, ?, ?)
            """,
            bindings: [
                profile.displayName.map(SQLValue.text) ?? .null,
                profile.responseStyle.map(SQLValue.text) ?? .null,
                profile.generalNotes.map(SQLValue.text) ?? .null,
                .text(profile.updatedAt),
            ]
        )
        return profile
    }

    // MARK: - Personality settings

    public func getPersonalitySettings() -> PersonalitySettingsRecord? {
        queryOne(
            """
            SELECT active_preset_id, custom_prompt, updated_at
            FROM personality_settings WHERE id = 'default' LIMIT 1
            """,
            map: Self.mapPersonalitySettings
        )
    }

    @discardableResult
    public func savePersonalitySettings(activePresetID: String, customPrompt: String?) -> PersonalitySettingsRecord {
        let settings = PersonalitySettingsRecord(
            activePresetID: activePresetID,
            customPrompt: Self.normalizedOptional(customPrompt),
            updatedAt: Self.now()
        )

        execute("DELETE FROM personality_settings WHERE id = 'default'")
        execute(
            """
            INSERT INTO personality_settings (id, active_preset_id, custom_prompt, updated_at)
            VALUES ('default', ?, ?, ?)
            """,
            bindings: [
                .text(settings.activePresetID),
                settings.customPrompt.map(SQLValue.text) ?? .null,
                .text(settings.updatedAt),
            ]
        )
        return settings
    }

    // MARK: - Knowledge volumes

    public func knowledgeVolumeExists(id: String) -> Bool {
        queryOne(
            "SELECT 1 FROM knowledge_volumes WHERE id = ? LIMIT 1",
            bindings: [.text(id)],
            map: { _ in true }
        ) != nil
    }

    @discardableResult
    public func installKnowledgeVolume(
        id: String,
        title: String,
        version: String,
        summary: String?,
        tags: [String],
        sourceLabel: String?,
        records: [(id: String, title: String, content: String, tags: [String])],
        enabled: Bool = true
    ) -> KnowledgeVolumeRecord {
        let volume = KnowledgeVolumeRecord(
            id: id,
            title: title,
            version: version,
            summary: summary,
            tags: tags,
            sourceLabel: sourceLabel,
            isEnabled: enabled,
            installedAt: Self.now()
        )

        execute("DELETE FROM knowledge_records WHERE volume_id = ?", bindings: [.text(id)])
        execute("DELETE FROM knowledge_volumes WHERE id = ?", bindings: [.text(id)])

        execute(
            """
            INSERT INTO knowledge_volumes (id, title, version, summary, tags_json, source_label, is_enabled, installed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(volume.id),
                .text(volume.title),
                .text(version),
                volume.summary.map(SQLValue.text) ?? .null,
                .text(Self.encodeJSON(tags)),
                sourceLabel.map(SQLValue.text) ?? .null,
                .int(enabled ? 1 : 0),
                .text(volume.installedAt),
            ]
        )

        for record in records {
            execute(
                """
                INSERT INTO knowledge_records (id, volume_id, title, content, tags_json)
                VALUES (?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(record.id),
                    .text(id),
                    .text(record.title),
                    .text(record.content),
                    .text(Self.encodeJSON(record.tags)),
                ]
            )
        }

        return volume
    }

    public func listKnowledgeVolumes() -> [KnowledgeVolumeRecord] {
        queryMany(
            """
            SELECT id, title, version, summary, tags_json, source_label, is_enabled, installed_at
            FROM knowledge_volumes ORDER BY installed_at ASC
            """,
            map: Self.mapKnowledgeVolume
        )
    }

    public func listEnabledKnowledgeVolumes() -> [KnowledgeVolumeRecord] {
        queryMany(
            """
            SELECT id, title, version, summary, tags_json, source_label, is_enabled, installed_at
            FROM knowledge_volumes WHERE is_enabled = 1 ORDER BY installed_at ASC
            """,
            map: Self.mapKnowledgeVolume
        )
    }

    public func setKnowledgeVolumeEnabled(id: String, enabled: Bool) {
        execute(
            "UPDATE knowledge_volumes SET is_enabled = ? WHERE id = ?",
            bindings: [.int(enabled ? 1 : 0), .text(id)]
        )
    }

    public func listKnowledgeRecords(volumeID: String) -> [StoredKnowledgeRecord] {
        queryMany(
            """
            SELECT id, volume_id, title, content, tags_json
            FROM knowledge_records WHERE volume_id = ? ORDER BY title ASC
            """,
            bindings: [.text(volumeID)],
            map: Self.mapKnowledgeRecord
        )
    }

    public func countKnowledgeRecords(volumeID: String) -> Int {
        queryOne(
            "SELECT COUNT(*) FROM knowledge_records WHERE volume_id = ?",
            bindings: [.text(volumeID)],
            map: { Int(sqlite3_column_int($0, 0)) }
        ) ?? 0
    }

    public func enabledKnowledgeVolumesWithRecords() -> [(KnowledgeVolumeRecord, [StoredKnowledgeRecord])] {
        listEnabledKnowledgeVolumes().map { volume in
            (volume, listKnowledgeRecords(volumeID: volume.id))
        }
    }

    public func addMessageKnowledgeSources(
        messageID: String,
        sources: [(volumeID: String, volumeTitle: String, recordID: String, recordTitle: String, excerpt: String)]
    ) {
        for source in sources {
            execute(
                """
                INSERT INTO message_knowledge_sources
                (id, message_id, volume_id, volume_title, record_id, record_title, excerpt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                bindings: [
                    .text(Self.newID()),
                    .text(messageID),
                    .text(source.volumeID),
                    .text(source.volumeTitle),
                    .text(source.recordID),
                    .text(source.recordTitle),
                    .text(source.excerpt),
                ]
            )
        }
    }

    public func listMessageKnowledgeSources(messageID: String) -> [MessageKnowledgeSourceRecord] {
        queryMany(
            """
            SELECT id, message_id, volume_id, volume_title, record_id, record_title, excerpt
            FROM message_knowledge_sources WHERE message_id = ? ORDER BY record_title ASC
            """,
            bindings: [.text(messageID)],
            map: Self.mapMessageKnowledgeSource
        )
    }

    public func listMessageKnowledgeSources(forSession sessionID: String) -> [MessageKnowledgeSourceRecord] {
        queryMany(
            """
            SELECT s.id, s.message_id, s.volume_id, s.volume_title, s.record_id, s.record_title, s.excerpt
            FROM message_knowledge_sources s
            JOIN messages m ON m.id = s.message_id
            WHERE m.session_id = ?
            ORDER BY m.ts ASC, s.record_title ASC
            """,
            bindings: [.text(sessionID)],
            map: Self.mapMessageKnowledgeSource
        )
    }

    // MARK: - Helpers

    private enum SQLValue {
        case text(String)
        case int(Int)
        case null
    }

    private func execute(_ sql: String, bindings: [SQLValue] = []) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("SQLite prepare failed: \(Database.lastError(from: connection))")
        }
        defer { sqlite3_finalize(statement) }

        bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            fatalError("SQLite execute failed: \(Database.lastError(from: connection))")
        }
    }

    private func queryOne<T>(
        _ sql: String,
        bindings: [SQLValue] = [],
        map: (OpaquePointer) -> T
    ) -> T? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("SQLite prepare failed: \(Database.lastError(from: connection))")
        }
        defer { sqlite3_finalize(statement) }

        bind(bindings, to: statement)
        guard sqlite3_step(statement) == SQLITE_ROW, let statement else {
            return nil
        }
        return map(statement)
    }

    private func queryMany<T>(
        _ sql: String,
        bindings: [SQLValue] = [],
        map: (OpaquePointer) -> T
    ) -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            fatalError("SQLite prepare failed: \(Database.lastError(from: connection))")
        }
        defer { sqlite3_finalize(statement) }

        bind(bindings, to: statement)

        var rows: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW, let statement {
            rows.append(map(statement))
        }
        return rows
    }

    private func bind(_ bindings: [SQLValue], to statement: OpaquePointer?) {
        for (index, value) in bindings.enumerated() {
            let position = Int32(index + 1)
            switch value {
            case let .text(text):
                sqlite3_bind_text(statement, position, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case let .int(number):
                sqlite3_bind_int(statement, position, Int32(number))
            case .null:
                sqlite3_bind_null(statement, position)
            }
        }
    }

    private static func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func mapSession(_ statement: OpaquePointer) -> SessionRecord {
        SessionRecord(
            id: columnText(statement, 0),
            startedAt: columnText(statement, 1),
            endedAt: columnOptionalText(statement, 2),
            status: columnText(statement, 3)
        )
    }

    private static func mapMessage(_ statement: OpaquePointer) -> MessageRecord {
        MessageRecord(
            id: columnText(statement, 0),
            sessionID: columnText(statement, 1),
            timestamp: columnText(statement, 2),
            role: columnText(statement, 3),
            content: columnText(statement, 4),
            source: columnText(statement, 5),
            imagePath: columnOptionalText(statement, 6),
            ocrText: columnOptionalText(statement, 7),
            visualObservationsJSON: columnOptionalText(statement, 8),
            locationJSON: columnOptionalText(statement, 9),
            promptVersionID: columnOptionalText(statement, 10),
            latencyMs: columnOptionalInt(statement, 11),
            cancelled: sqlite3_column_int(statement, 12) != 0
        )
    }

    private static func mapPromptVersion(_ statement: OpaquePointer) -> PromptVersionRecord {
        PromptVersionRecord(
            id: columnText(statement, 0),
            content: columnText(statement, 1),
            label: columnOptionalText(statement, 2),
            createdAt: columnText(statement, 3),
            isActive: sqlite3_column_int(statement, 4) != 0
        )
    }

    private static func mapMemoryFact(_ statement: OpaquePointer) -> MemoryFactRecord {
        MemoryFactRecord(
            id: columnText(statement, 0),
            text: columnText(statement, 1),
            createdAt: columnText(statement, 2),
            active: sqlite3_column_int(statement, 3) != 0
        )
    }

    private static func mapUserProfile(_ statement: OpaquePointer) -> UserProfileRecord {
        UserProfileRecord(
            displayName: columnOptionalText(statement, 0),
            responseStyle: columnOptionalText(statement, 1),
            generalNotes: columnOptionalText(statement, 2),
            updatedAt: columnText(statement, 3)
        )
    }

    private static func mapPersonalitySettings(_ statement: OpaquePointer) -> PersonalitySettingsRecord {
        PersonalitySettingsRecord(
            activePresetID: columnText(statement, 0),
            customPrompt: columnOptionalText(statement, 1),
            updatedAt: columnText(statement, 2)
        )
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func mapKnowledgeVolume(_ statement: OpaquePointer) -> KnowledgeVolumeRecord {
        KnowledgeVolumeRecord(
            id: columnText(statement, 0),
            title: columnText(statement, 1),
            version: columnOptionalText(statement, 2),
            summary: columnOptionalText(statement, 3),
            tags: decodeJSON(columnText(statement, 4), as: [String].self) ?? [],
            sourceLabel: columnOptionalText(statement, 5),
            isEnabled: sqlite3_column_int(statement, 6) != 0,
            installedAt: columnText(statement, 7)
        )
    }

    private static func mapKnowledgeRecord(_ statement: OpaquePointer) -> StoredKnowledgeRecord {
        StoredKnowledgeRecord(
            id: columnText(statement, 0),
            volumeID: columnText(statement, 1),
            title: columnText(statement, 2),
            content: columnText(statement, 3),
            tags: decodeJSON(columnText(statement, 4), as: [String].self) ?? []
        )
    }

    private static func mapMessageKnowledgeSource(_ statement: OpaquePointer) -> MessageKnowledgeSourceRecord {
        MessageKnowledgeSourceRecord(
            id: columnText(statement, 0),
            messageID: columnText(statement, 1),
            volumeID: columnText(statement, 2),
            volumeTitle: columnText(statement, 3),
            recordID: columnText(statement, 4),
            recordTitle: columnText(statement, 5),
            excerpt: columnText(statement, 6)
        )
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private static func decodeJSON<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func columnText(_ statement: OpaquePointer, _ index: Int32) -> String {
        String(cString: sqlite3_column_text(statement, index))
    }

    private static func columnOptionalText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return columnText(statement, index)
    }

    private static func columnOptionalInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Int(sqlite3_column_int(statement, index))
    }
}
