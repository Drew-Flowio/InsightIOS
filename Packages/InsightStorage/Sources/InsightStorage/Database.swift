import Foundation
import SQLite3

enum Database {
    static let schema = """
    CREATE TABLE IF NOT EXISTS sessions (
        id          TEXT PRIMARY KEY,
        started_at  TEXT NOT NULL,
        ended_at    TEXT,
        status      TEXT NOT NULL DEFAULT 'active'
    );

    CREATE TABLE IF NOT EXISTS prompt_versions (
        id          TEXT PRIMARY KEY,
        content     TEXT NOT NULL,
        label       TEXT,
        created_at  TEXT NOT NULL,
        is_active   INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS messages (
        id                  TEXT PRIMARY KEY,
        session_id          TEXT NOT NULL REFERENCES sessions(id),
        ts                  TEXT NOT NULL,
        role                TEXT NOT NULL,
        content             TEXT NOT NULL,
        source              TEXT NOT NULL DEFAULT 'text',
        prompt_version_id   TEXT REFERENCES prompt_versions(id),
        latency_ms          INTEGER,
        cancelled           INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS memory_facts (
        id          TEXT PRIMARY KEY,
        text        TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        active      INTEGER NOT NULL DEFAULT 1
    );

    CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id, ts);
    CREATE INDEX IF NOT EXISTS idx_prompt_versions_active ON prompt_versions(is_active);

    CREATE TABLE IF NOT EXISTS knowledge_volumes (
        id              TEXT PRIMARY KEY,
        title           TEXT NOT NULL,
        version         TEXT,
        summary         TEXT,
        tags_json       TEXT NOT NULL DEFAULT '[]',
        source_label    TEXT,
        is_enabled      INTEGER NOT NULL DEFAULT 1,
        installed_at    TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS knowledge_records (
        id              TEXT NOT NULL,
        volume_id       TEXT NOT NULL REFERENCES knowledge_volumes(id) ON DELETE CASCADE,
        title           TEXT NOT NULL,
        content         TEXT NOT NULL,
        tags_json       TEXT NOT NULL DEFAULT '[]',
        PRIMARY KEY (volume_id, id)
    );

    CREATE TABLE IF NOT EXISTS message_knowledge_sources (
        id              TEXT PRIMARY KEY,
        message_id      TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
        volume_id       TEXT NOT NULL,
        volume_title    TEXT NOT NULL,
        record_id       TEXT NOT NULL,
        record_title    TEXT NOT NULL,
        excerpt         TEXT NOT NULL
    );

    CREATE INDEX IF NOT EXISTS idx_knowledge_records_volume ON knowledge_records(volume_id);
    CREATE INDEX IF NOT EXISTS idx_message_knowledge_sources_message ON message_knowledge_sources(message_id);

    CREATE TABLE IF NOT EXISTS user_profile (
        id              TEXT PRIMARY KEY,
        display_name    TEXT,
        response_style  TEXT,
        general_notes   TEXT,
        updated_at      TEXT NOT NULL
    );
    """

    static func open(at path: String) throws -> OpaquePointer {
        var connection: OpaquePointer?
        if sqlite3_open(path, &connection) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        guard let connection else {
            throw StorageError.openFailed(message: "Missing database connection.")
        }

        if sqlite3_exec(connection, "PRAGMA foreign_keys = ON;", nil, nil, nil) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        if sqlite3_exec(connection, schema, nil, nil, nil) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        migrate(connection)

        return connection
    }

    static func openInMemory() throws -> OpaquePointer {
        var connection: OpaquePointer?
        if sqlite3_open(":memory:", &connection) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        guard let connection else {
            throw StorageError.openFailed(message: "Missing database connection.")
        }

        if sqlite3_exec(connection, "PRAGMA foreign_keys = ON;", nil, nil, nil) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        if sqlite3_exec(connection, schema, nil, nil, nil) != SQLITE_OK {
            throw StorageError.openFailed(message: lastError(from: connection))
        }

        migrate(connection)

        return connection
    }

    private static func migrate(_ connection: OpaquePointer) {
        _ = sqlite3_exec(connection, "ALTER TABLE knowledge_volumes ADD COLUMN version TEXT", nil, nil, nil)
        _ = sqlite3_exec(connection, "ALTER TABLE messages ADD COLUMN image_path TEXT", nil, nil, nil)
        _ = sqlite3_exec(connection, "ALTER TABLE messages ADD COLUMN ocr_text TEXT", nil, nil, nil)
    }

    static func lastError(from connection: OpaquePointer?) -> String {
        guard let connection, let message = sqlite3_errmsg(connection) else {
            return "Unknown SQLite error."
        }
        return String(cString: message)
    }
}

public enum StorageError: Error, Equatable {
    case openFailed(message: String)
    case queryFailed(message: String)
}
