// SPDX-License-Identifier: MPL-2.0
import Foundation
import SQLite3

public enum SQLiteStoreError: Error, Sendable {
    case openFailed(String)
    case execFailed(String)
}

public final class SQLiteStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    public let databasePath: String

    public init(path: String? = nil) throws {
        if let path {
            self.databasePath = path
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("dev.v1torres.timbr", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.databasePath = dir.appendingPathComponent("timbr.sqlite").path
        }
        var handle: OpaquePointer?
        if sqlite3_open(databasePath, &handle) != SQLITE_OK {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw SQLiteStoreError.openFailed(msg)
        }
        self.db = handle
        try migrate()
    }

    deinit {
        lock.lock()
        if let db { sqlite3_close(db) }
        lock.unlock()
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "sql error"
            sqlite3_free(errMsg)
            throw SQLiteStoreError.execFailed(msg)
        }
    }

    private func migrate() throws {
        lock.lock()
        defer { lock.unlock() }
        try exec("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS kv_store (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS observatory_events (
            id TEXT PRIMARY KEY,
            timestamp REAL NOT NULL,
            category TEXT NOT NULL,
            message TEXT NOT NULL,
            badge TEXT,
            device_uid TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_events_ts ON observatory_events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_events_cat_ts ON observatory_events(category, timestamp);
        CREATE TABLE IF NOT EXISTS listening_days (
            day TEXT PRIMARY KEY,
            personal_seconds REAL NOT NULL DEFAULT 0,
            high_seconds REAL NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS presets (
            id TEXT PRIMARY KEY,
            device_uid TEXT,
            name TEXT NOT NULL,
            json_blob TEXT NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE TABLE IF NOT EXISTS muted_guardian_pairs (
            pair_key TEXT PRIMARY KEY,
            created_at REAL NOT NULL
        );
        """)
        try migrateEventSearch()
    }

    /// Full-text search over the timeline (ADR-0018): FTS5 with the `trigram` tokenizer, so any
    /// 3+ character fragment matches ("spea" finds "Speakers"), case-insensitively, through an index
    /// instead of a table scan. External-content: the text is not stored twice. If this SQLite has
    /// no FTS5/trigram, search silently falls back to a plain `LIKE` (see `EventLogReader`).
    private func migrateEventSearch() throws {
        var stmt: OpaquePointer?
        let exists: Bool = {
            guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE name = 'observatory_events_fts';", -1, &stmt, nil) == SQLITE_OK else { return false }
            defer { sqlite3_finalize(stmt) }
            return sqlite3_step(stmt) == SQLITE_ROW
        }()
        do {
            try exec("""
            CREATE VIRTUAL TABLE IF NOT EXISTS observatory_events_fts USING fts5(
                message, category, content='observatory_events', content_rowid='rowid', tokenize='trigram'
            );
            CREATE TRIGGER IF NOT EXISTS observatory_events_ai AFTER INSERT ON observatory_events BEGIN
                INSERT INTO observatory_events_fts(rowid, message, category) VALUES (new.rowid, new.message, new.category);
            END;
            CREATE TRIGGER IF NOT EXISTS observatory_events_ad AFTER DELETE ON observatory_events BEGIN
                INSERT INTO observatory_events_fts(observatory_events_fts, rowid, message, category) VALUES ('delete', old.rowid, old.message, old.category);
            END;
            """)
            if !exists { try exec("INSERT INTO observatory_events_fts(observatory_events_fts) VALUES ('rebuild');") }   // index what was logged before
        } catch {
            // No FTS5 here: keep the app working, search degrades to LIKE.
            try? exec("DROP TRIGGER IF EXISTS observatory_events_ai; DROP TRIGGER IF EXISTS observatory_events_ad;")
        }
    }

    public func saveEvent(_ ev: ObservatoryEvent) throws {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR IGNORE INTO observatory_events (id, timestamp, category, message, badge, device_uid) VALUES (?, ?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, ev.id.uuidString, -1, transient)
        sqlite3_bind_double(stmt, 2, ev.timestamp.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 3, ev.category, -1, transient)
        sqlite3_bind_text(stmt, 4, ev.message, -1, transient)
        if let b = ev.badge?.rawValue {
            sqlite3_bind_text(stmt, 5, b, -1, transient)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        if let d = ev.deviceUID {
            sqlite3_bind_text(stmt, 6, d, -1, transient)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        sqlite3_step(stmt)
    }

    public func loadRecentEvents(limit: Int = 100) -> [ObservatoryEvent] {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT id, timestamp, category, message, badge, device_uid FROM observatory_events ORDER BY timestamp DESC LIMIT ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))
        var out: [ObservatoryEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            let ts = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let cat = String(cString: sqlite3_column_text(stmt, 2))
            let msg = String(cString: sqlite3_column_text(stmt, 3))
            let badge: SignalTrustBadge? = sqlite3_column_type(stmt, 4) != SQLITE_NULL
                ? SignalTrustBadge(rawValue: String(cString: sqlite3_column_text(stmt, 4)))
                : nil
            let uid: String? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
                ? String(cString: sqlite3_column_text(stmt, 5))
                : nil
            out.append(ObservatoryEvent(
                id: UUID(uuidString: idStr) ?? UUID(),
                timestamp: ts,
                category: cat,
                message: msg,
                badge: badge,
                deviceUID: uid
            ))
        }
        return out
    }

    // MARK: Listening time (ADR-0023)

    /// Adds seconds to a day (creating it). Called every ~30 s with what the tracker accumulated.
    public func addListening(day: String, personal: Double, high: Double) {
        lock.lock()
        defer { lock.unlock() }
        let sql = """
        INSERT INTO listening_days (day, personal_seconds, high_seconds) VALUES (?, ?, ?)
        ON CONFLICT(day) DO UPDATE SET personal_seconds = personal_seconds + excluded.personal_seconds,
                                       high_seconds = high_seconds + excluded.high_seconds;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, day, -1, transient)
        sqlite3_bind_double(stmt, 2, personal)
        sqlite3_bind_double(stmt, 3, high)
        sqlite3_step(stmt)
    }

    /// The most recent `days` days that have data, newest first.
    public func loadListening(days: Int = 7) -> [ListeningDay] {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT day, personal_seconds, high_seconds FROM listening_days ORDER BY day DESC LIMIT ?;", -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(days))
        var out: [ListeningDay] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(ListeningDay(day: String(cString: sqlite3_column_text(stmt, 0)),
                                    personalSeconds: sqlite3_column_double(stmt, 1), highSeconds: sqlite3_column_double(stmt, 2)))
        }
        return out
    }

    public func savePreset(_ preset: TimbrePreset) throws {
        lock.lock()
        defer { lock.unlock() }
        let data = try JSONEncoder().encode(preset)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        let sql = "INSERT OR REPLACE INTO presets (id, device_uid, name, json_blob, updated_at) VALUES (?, ?, ?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, preset.id.uuidString, -1, transient)
        if let d = preset.deviceUID {
            sqlite3_bind_text(stmt, 2, d, -1, transient)
        } else {
            sqlite3_bind_null(stmt, 2)
        }
        sqlite3_bind_text(stmt, 3, preset.name, -1, transient)
        sqlite3_bind_text(stmt, 4, json, -1, transient)
        sqlite3_bind_double(stmt, 5, preset.updatedAt.timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    public func deletePreset(id: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        let sql = "DELETE FROM presets WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, transient)
        sqlite3_step(stmt)
    }

    public func loadPresets() -> [TimbrePreset] {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT json_blob FROM presets ORDER BY updated_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [TimbrePreset] = []
        let decoder = JSONDecoder()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let json = String(cString: sqlite3_column_text(stmt, 0))
            if let data = json.data(using: .utf8),
               let p = try? decoder.decode(TimbrePreset.self, from: data) {
                out.append(p)
            }
        }
        return out
    }

    public func muteGuardianPair(_ pairKey: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR REPLACE INTO muted_guardian_pairs (pair_key, created_at) VALUES (?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, pairKey, -1, transient)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    public func loadMutedPairs() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT pair_key FROM muted_guardian_pairs;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.insert(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return out
    }

    public func setKV(_ key: String, value: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let sql = "INSERT OR REPLACE INTO kv_store (key, value, updated_at) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key, -1, transient)
        sqlite3_bind_text(stmt, 2, value, -1, transient)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    public func getKV(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        let sql = "SELECT value FROM kv_store WHERE key = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    public func clearAllHistory() throws {
        lock.lock()
        defer { lock.unlock() }
        try exec("DELETE FROM observatory_events; DELETE FROM muted_guardian_pairs; DELETE FROM kv_store; DELETE FROM listening_days;")
    }
}
