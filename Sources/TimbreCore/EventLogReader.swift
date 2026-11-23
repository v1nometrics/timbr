// SPDX-License-Identifier: MPL-2.0
// Observatory timeline queries (ADR-0018): keyset pagination, search, category filter, streamed export.
//
// Why this is its own object with its own connection:
//  - SQLiteStore serialises everything behind one lock and `logEvent` runs on the main thread. A
//    search or an export holding that lock would freeze the app. SQLite in WAL mode lets a separate
//    read-only connection read while the writer keeps writing, so the UI never waits on a query.
//  - Pages use a keyset cursor `(timestamp, rowid)` instead of OFFSET: page 5,000 costs the same as
//    page 1, and a row logged meanwhile cannot shift or duplicate what is already on screen.
import Foundation
import SQLite3

public struct EventFilter: Equatable, Sendable {
    public var text: String
    public var categories: Set<String>

    public init(text: String = "", categories: Set<String> = []) {
        self.text = text
        self.categories = categories
    }

    /// Shortest fragment the trigram index can look up.
    public static let minSearchLength = 3

    /// The search term, trimmed, or nil while it is too short to search.
    public var searchTerm: String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count >= Self.minSearchLength ? t : nil
    }

    /// The user typed something, but not enough to search yet.
    public var searchTooShort: Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count < Self.minSearchLength
    }

    public var isEmpty: Bool { searchTerm == nil && categories.isEmpty }
}

public struct EventCursor: Equatable, Hashable, Sendable {
    public let timestamp: Double
    public let rowid: Int64
    public init(timestamp: Double, rowid: Int64) { self.timestamp = timestamp; self.rowid = rowid }
}

public struct EventRow: Identifiable, Equatable, Sendable {
    public let event: ObservatoryEvent
    public let cursor: EventCursor
    public var id: UUID { event.id }
}

public struct EventPage: Sendable {
    public let rows: [EventRow]
    public let hasMore: Bool
}

public enum EventExportFormat: Sendable {
    case csv, json

    public var fileExtension: String { self == .csv ? "csv" : "json" }
}

public final class EventLogReader: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    public let path: String
    private let ftsAvailable: Bool

    private static let columns = "e.rowid, e.id, e.timestamp, e.category, e.message, e.badge, e.device_uid"

    public init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK, let handle else {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let handle { sqlite3_close(handle) }
            throw SQLiteStoreError.openFailed(msg)
        }
        sqlite3_busy_timeout(handle, 2000)   // the writer may hold a brief lock
        self.db = handle
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        ftsAvailable = sqlite3_prepare_v2(handle, "SELECT 1 FROM sqlite_master WHERE name = 'observatory_events_fts';", -1, &stmt, nil) == SQLITE_OK
            && sqlite3_step(stmt) == SQLITE_ROW
    }

    deinit { if let db { sqlite3_close(db) } }

    // MARK: Queries

    /// One page of events, newest first, strictly older than `after` (nil = from the newest).
    public func page(filter: EventFilter, after: EventCursor? = nil, limit: Int = 100) -> EventPage {
        var (sql, binds) = Self.select(filter: filter, fts: ftsAvailable)
        if let after {
            sql += " AND (e.timestamp, e.rowid) < (?, ?)"   // tuple compare: one index seek, not a scan
            binds += [.double(after.timestamp), .int(after.rowid)]
        }
        sql += " ORDER BY e.timestamp DESC, e.rowid DESC LIMIT ?"
        binds.append(.int(Int64(limit + 1)))   // one extra row says whether there is a next page
        var rows = run(sql, binds)
        let hasMore = rows.count > limit
        if hasMore { rows.removeLast() }
        return EventPage(rows: rows, hasMore: hasMore)
    }

    /// Events newer than `than`, newest first: the live head of the timeline.
    public func newer(filter: EventFilter, than: EventCursor, limit: Int = 200) -> [EventRow] {
        var (sql, binds) = Self.select(filter: filter, fts: ftsAvailable)
        sql += " AND (e.timestamp, e.rowid) > (?, ?) ORDER BY e.timestamp ASC, e.rowid ASC LIMIT ?"
        binds += [.double(than.timestamp), .int(than.rowid), .int(Int64(limit))]
        return run(sql, binds).reversed()
    }

    public func count(filter: EventFilter) -> Int {
        var (sql, binds) = Self.select(filter: filter, fts: ftsAvailable, projection: "COUNT(*)")
        _ = binds
        lock.lock(); defer { lock.unlock() }
        guard let stmt = prepare(&sql, binds) else { return 0 }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW ? Int(sqlite3_column_int64(stmt, 0)) : 0
    }

    public func categories() -> [String] {
        lock.lock(); defer { lock.unlock() }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT DISTINCT category FROM observatory_events ORDER BY category;", -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(String(cString: sqlite3_column_text(stmt, 0))) }
        return out
    }

    // MARK: Export

    /// Streams every event matching `filter` (oldest first) to `url`, 1,000 rows at a time, on its own
    /// connection: memory stays flat and the timeline keeps working while a large export runs.
    /// Returns the number of events written. `isCancelled` is polled between batches.
    @discardableResult
    public static func export(
        databasePath: String, filter: EventFilter, format: EventExportFormat, to url: URL,
        isCancelled: @Sendable () -> Bool = { false }
    ) throws -> Int {
        let reader = try EventLogReader(path: databasePath)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).partial")
        FileManager.default.createFile(atPath: tmp.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tmp)
        var finished = false
        defer {
            try? handle.close()
            if !finished { try? FileManager.default.removeItem(at: tmp) }   // never leave a half file under the real name
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var buffer = Data()
        func emit(_ s: String) { buffer.append(Data(s.utf8)) }
        func flush() throws { if !buffer.isEmpty { try handle.write(contentsOf: buffer); buffer.removeAll(keepingCapacity: true) } }

        switch format {
        case .csv: emit("timestamp,category,message,badge,device_uid\r\n")
        case .json: emit("[")
        }

        var written = 0
        var cursor: EventCursor?   // oldest-first keyset
        while !isCancelled() {
            var (sql, binds) = Self.select(filter: filter, fts: reader.ftsAvailable)
            if let c = cursor {
                sql += " AND (e.timestamp, e.rowid) > (?, ?)"
                binds += [.double(c.timestamp), .int(c.rowid)]
            }
            sql += " ORDER BY e.timestamp ASC, e.rowid ASC LIMIT 1000"
            let rows = reader.run(sql, binds)
            if rows.isEmpty { break }
            for r in rows {
                let e = r.event
                switch format {
                case .csv:
                    emit([iso.string(from: e.timestamp), e.category, e.message, e.badge?.rawValue ?? "", e.deviceUID ?? ""]
                        .map(csvCell).joined(separator: ",") + "\r\n")
                case .json:
                    let obj: [String: Any] = [
                        "id": e.id.uuidString, "timestamp": iso.string(from: e.timestamp), "category": e.category,
                        "message": e.message, "badge": e.badge?.rawValue ?? NSNull(), "deviceUID": e.deviceUID ?? NSNull(),
                    ]
                    let data = try JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])
                    emit((written == 0 ? "\n  " : ",\n  ") + String(decoding: data, as: UTF8.self))
                }
                written += 1
            }
            try flush()
            cursor = rows.last?.cursor
        }
        if isCancelled() { throw CancellationError() }
        if format == .json { emit(written == 0 ? "]\n" : "\n]\n") }
        try flush()
        try handle.close()
        _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
        if !FileManager.default.fileExists(atPath: url.path) { try FileManager.default.moveItem(at: tmp, to: url) }
        finished = true
        return written
    }

    /// RFC 4180 quoting, plus a leading `'` on cells a spreadsheet would run as a formula.
    static func csvCell(_ raw: String) -> String {
        var s = raw
        if let f = s.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(f) { s = "'" + s }
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            s = "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    // MARK: SQL building

    enum Bind { case text(String), double(Double), int(Int64) }

    /// `SELECT … FROM observatory_events e WHERE 1=1 [filters]`; callers append keyset/order/limit.
    static func select(filter: EventFilter, fts: Bool, projection: String = columns) -> (String, [Bind]) {
        var sql = "SELECT \(projection) FROM observatory_events e WHERE 1=1"
        var binds: [Bind] = []
        if !filter.categories.isEmpty {
            sql += " AND e.category IN (" + Array(repeating: "?", count: filter.categories.count).joined(separator: ",") + ")"
            binds += filter.categories.sorted().map { .text($0) }
        }
        if let term = filter.searchTerm {
            if fts {
                // One quoted phrase: the whole text is a substring, with spaces, as the user typed it.
                sql += " AND e.rowid IN (SELECT rowid FROM observatory_events_fts WHERE observatory_events_fts MATCH ?)"
                binds.append(.text("\"" + term.replacingOccurrences(of: "\"", with: "\"\"") + "\""))
            } else {
                sql += " AND (e.message LIKE ? ESCAPE '\\' OR e.category LIKE ? ESCAPE '\\')"
                let like = "%" + term.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_") + "%"
                binds += [.text(like), .text(like)]
            }
        }
        return (sql, binds)
    }

    private func prepare(_ sql: inout String, _ binds: [Bind]) -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (i, b) in binds.enumerated() {
            let idx = Int32(i + 1)
            switch b {
            case .text(let t): sqlite3_bind_text(stmt, idx, t, -1, transient)
            case .double(let d): sqlite3_bind_double(stmt, idx, d)
            case .int(let n): sqlite3_bind_int64(stmt, idx, n)
            }
        }
        return stmt
    }

    private func run(_ sql: String, _ binds: [Bind]) -> [EventRow] {
        lock.lock(); defer { lock.unlock() }
        var q = sql
        guard let stmt = prepare(&q, binds) else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [EventRow] = []
        func text(_ i: Int32) -> String? { sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, i)) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            let ts = sqlite3_column_double(stmt, 2)
            out.append(EventRow(
                event: ObservatoryEvent(
                    id: UUID(uuidString: text(1) ?? "") ?? UUID(),
                    timestamp: Date(timeIntervalSince1970: ts),
                    category: text(3) ?? "",
                    message: text(4) ?? "",
                    badge: text(5).flatMap(SignalTrustBadge.init(rawValue:)),
                    deviceUID: text(6)),
                cursor: EventCursor(timestamp: ts, rowid: sqlite3_column_int64(stmt, 0))))
        }
        return out
    }
}
