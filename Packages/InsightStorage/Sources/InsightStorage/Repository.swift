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
            promptVersionID: promptVersionID,
            latencyMs: latencyMs,
            cancelled: cancelled
        )
        execute(
            """
            INSERT INTO messages
            (id, session_id, ts, role, content, source, prompt_version_id, latency_ms, cancelled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            bindings: [
                .text(message.id),
                .text(message.sessionID),
                .text(message.timestamp),
                .text(message.role),
                .text(message.content),
                .text(message.source),
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
            SELECT id, session_id, ts, role, content, source, prompt_version_id, latency_ms, cancelled
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
            promptVersionID: columnOptionalText(statement, 6),
            latencyMs: columnOptionalInt(statement, 7),
            cancelled: sqlite3_column_int(statement, 8) != 0
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
