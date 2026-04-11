import Foundation
import SQLite3

// SQLITE_TRANSIENT: SQLite copies the string on bind, so no dangling-pointer risk.
private let SQLITE_TRANSIENT = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)

/// Thread-safe SQLite persistence layer.
///
/// Implemented as a plain `final class` (not `actor`) so that the dedicated
/// serial `DispatchQueue` — not Swift's cooperative thread pool — owns every
/// SQLite call.  Blocking I/O on the cooperative pool starves other async work;
/// routing it to a utility-QoS DispatchQueue avoids that entirely.
///
/// All public methods are `async`: callers `await` them as before, but the
/// bodies execute synchronously on `queue` via a `CheckedContinuation`.
final class DatabaseService: @unchecked Sendable {

    static let shared = DatabaseService()

    /// Every SQLite access is serialised through this queue.
    private let queue = DispatchQueue(label: "com.photocleaner.db", qos: .utility)
    private var db: OpaquePointer?

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("photocleaner.sqlite").path
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS photo_scores (
                local_id         TEXT PRIMARY KEY,
                score            INTEGER NOT NULL,
                is_blurry        INTEGER NOT NULL DEFAULT 0,
                is_over_exposed  INTEGER NOT NULL DEFAULT 0,
                is_under_exposed INTEGER NOT NULL DEFAULT 0,
                has_faces        INTEGER NOT NULL DEFAULT 0,
                file_size_bytes  INTEGER,
                scored_at        INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS photo_groups (
                group_id   TEXT NOT NULL,
                local_id   TEXT NOT NULL,
                group_type TEXT NOT NULL,
                rank       INTEGER NOT NULL,
                PRIMARY KEY (group_id, local_id)
            );
            CREATE INDEX IF NOT EXISTS idx_groups_type ON photo_groups(group_type);
            CREATE TABLE IF NOT EXISTS scan_records (
                id                INTEGER PRIMARY KEY AUTOINCREMENT,
                scanned_at        INTEGER NOT NULL,
                total_count       INTEGER NOT NULL,
                duplicate_count   INTEGER NOT NULL,
                similar_count     INTEGER NOT NULL,
                low_quality_count INTEGER NOT NULL,
                freeable_bytes    INTEGER NOT NULL,
                health_score      INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS delete_records (
                local_id   TEXT NOT NULL,
                deleted_at INTEGER NOT NULL,
                size_bytes INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_delete_date ON delete_records(deleted_at);
            CREATE TABLE IF NOT EXISTS asset_scan_state (
                local_id         TEXT PRIMARY KEY,
                first_scanned_at INTEGER NOT NULL,
                last_scanned_at  INTEGER NOT NULL,
                is_deleted       INTEGER NOT NULL DEFAULT 0,
                deleted_at       INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_asset_scan_deleted ON asset_scan_state(is_deleted);
        """, nil, nil, nil)

        // Safe migrations: only add missing columns (prevents duplicate-column errors on relaunch).
        if !columnExists(table: "photo_scores", column: "has_faces") {
            sqlite3_exec(db, "ALTER TABLE photo_scores ADD COLUMN has_faces INTEGER NOT NULL DEFAULT 0", nil, nil, nil)
        }
        if !columnExists(table: "photo_scores", column: "file_size_bytes") {
            sqlite3_exec(db, "ALTER TABLE photo_scores ADD COLUMN file_size_bytes INTEGER", nil, nil, nil)
        }
    }

    // MARK: - Queue helper

    /// Dispatches `work` onto the serial queue and suspends the caller until it finishes.
    /// Use this for every public method so SQLite I/O never touches the cooperative pool.
    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { cont in
            queue.async { cont.resume(returning: work()) }
        }
    }

    private func columnExists(table: String, column: String) -> Bool {
        var stmt: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cName = sqlite3_column_text(stmt, 1) else { continue }
            if String(cString: cName) == column { return true }
        }
        return false
    }

    // MARK: - Photo Scores

    struct CachedScore {
        let score: Int
        let isBlurry: Bool
        let isOverExposed: Bool
        let isUnderExposed: Bool
        let hasFaces: Bool
        let fileSizeBytes: Int64?
    }

    struct ScoreEntry {
        let localId: String
        let score: Int
        let isBlurry: Bool
        let isOverExposed: Bool
        let isUnderExposed: Bool
        let hasFaces: Bool
        let fileSizeBytes: Int64?
    }

    /// Loads cached scores for a set of localIdentifiers.
    /// Batches the query in chunks of 500 to stay within SQLite's variable limit.
    func loadScores(for ids: [String]) async -> [String: CachedScore] {
        await run { self._loadScores(for: ids) }
    }

    private func _loadScores(for ids: [String]) -> [String: CachedScore] {
        var result: [String: CachedScore] = [:]
        let chunkSize = 500
        var offset = 0
        while offset < ids.count {
            let chunk = Array(ids[offset..<min(offset + chunkSize, ids.count)])
            let ph = chunk.map { _ in "?" }.joined(separator: ",")
            let sql = """
                SELECT local_id, score, is_blurry, is_over_exposed, is_under_exposed, has_faces, file_size_bytes
                FROM photo_scores WHERE local_id IN (\(ph))
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                for (i, id) in chunk.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), id, -1, SQLITE_TRANSIENT)
                }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    result[id] = CachedScore(
                        score:           Int(sqlite3_column_int(stmt, 1)),
                        isBlurry:        sqlite3_column_int(stmt, 2) != 0,
                        isOverExposed:   sqlite3_column_int(stmt, 3) != 0,
                        isUnderExposed:  sqlite3_column_int(stmt, 4) != 0,
                        hasFaces:        sqlite3_column_int(stmt, 5) != 0,
                        fileSizeBytes:   sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 6)
                    )
                }
                sqlite3_finalize(stmt)
            }
            offset += chunkSize
        }
        return result
    }

    func saveScores(_ entries: [ScoreEntry]) async {
        await run { self._saveScores(entries) }
    }

    private func _saveScores(_ entries: [ScoreEntry]) {
        guard !entries.isEmpty else { return }
        let sql = """
            INSERT OR REPLACE INTO photo_scores
                (local_id, score, is_blurry, is_over_exposed, is_under_exposed, has_faces, file_size_bytes, scored_at)
            VALUES (?,?,?,?,?,?,?,?)
        """
        _ = withTransaction("saveScores") {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare saveScores")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            let now = Int64(Date().timeIntervalSince1970)
            for e in entries {
                sqlite3_bind_text(stmt,  1, e.localId,         -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt,   2, Int32(e.score))
                sqlite3_bind_int(stmt,   3, e.isBlurry        ? 1 : 0)
                sqlite3_bind_int(stmt,   4, e.isOverExposed   ? 1 : 0)
                sqlite3_bind_int(stmt,   5, e.isUnderExposed  ? 1 : 0)
                sqlite3_bind_int(stmt,   6, e.hasFaces        ? 1 : 0)
                if let size = e.fileSizeBytes {
                    sqlite3_bind_int64(stmt, 7, size)
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                sqlite3_bind_int64(stmt, 8, now)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step saveScores")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    struct FileSizeEntry: Sendable {
        let localId: String
        let fileSizeBytes: Int64
    }

    func saveFileSizes(_ entries: [FileSizeEntry]) async {
        await run { self._saveFileSizes(entries) }
    }

    private func _saveFileSizes(_ entries: [FileSizeEntry]) {
        guard !entries.isEmpty else { return }
        let sql = "UPDATE photo_scores SET file_size_bytes=? WHERE local_id=?"
        _ = withTransaction("saveFileSizes") {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare saveFileSizes")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            for e in entries {
                sqlite3_bind_int64(stmt, 1, e.fileSizeBytes)
                sqlite3_bind_text(stmt,  2, e.localId, -1, SQLITE_TRANSIENT)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step saveFileSizes")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    func removeScores(for ids: [String]) async {
        await run { self._removeScores(for: ids) }
    }

    private func _removeScores(for ids: [String]) {
        guard !ids.isEmpty else { return }
        _ = withTransaction("removeScores") {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM photo_scores WHERE local_id=?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare removeScores")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            for id in ids {
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step removeScores")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    // MARK: - Photo Groups (duplicate / similar)

    func saveGroups(_ groups: [PhotoGroup]) async {
        await run { self._saveGroups(groups) }
    }

    private func _saveGroups(_ groups: [PhotoGroup]) {
        guard exec("BEGIN") == SQLITE_OK else { return }
        var shouldCommit = false
        defer {
            if shouldCommit {
                _ = exec("COMMIT")
            } else {
                _ = exec("ROLLBACK")
            }
        }

        guard exec("DELETE FROM photo_groups") == SQLITE_OK else { return }
        guard !groups.isEmpty else {
            shouldCommit = true
            return
        }

        let sql = "INSERT OR IGNORE INTO photo_groups (group_id,local_id,group_type,rank) VALUES (?,?,?,?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logSQLiteError("prepare saveGroups insert")
            return
        }
        defer { sqlite3_finalize(stmt) }

        for g in groups {
            let gid   = g.id.uuidString
            let gtype = g.groupType == .duplicate ? "duplicate" : "similar"
            for (rank, asset) in g.assets.enumerated() {
                sqlite3_bind_text(stmt, 1, gid,      -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, asset.id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, gtype,    -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt,  4, Int32(rank))
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step saveGroups insert")
                    return
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
        }
        shouldCommit = true
    }

    struct GroupRow {
        let groupId: String
        let localId: String
        let groupType: String
        let rank: Int
    }

    func loadGroupRows() async -> [GroupRow] {
        await run { self._loadGroupRows() }
    }

    private func _loadGroupRows() -> [GroupRow] {
        let sql = "SELECT group_id,local_id,group_type,rank FROM photo_groups ORDER BY group_id,rank"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var rows: [GroupRow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(GroupRow(
                groupId:   String(cString: sqlite3_column_text(stmt, 0)),
                localId:   String(cString: sqlite3_column_text(stmt, 1)),
                groupType: String(cString: sqlite3_column_text(stmt, 2)),
                rank:      Int(sqlite3_column_int(stmt, 3))
            ))
        }
        return rows
    }

    // MARK: - Scan Records

    struct ScanRecord {
        let scannedAt: Date
        let totalCount: Int
        let duplicateCount: Int
        let similarCount: Int
        let lowQualityCount: Int
        let freeableBytes: Int64
        let healthScore: Int
    }

    func saveScanRecord(summary: LibrarySummary, duplicateCount: Int, similarCount: Int, lowQualityCount: Int) async {
        await run { self._saveScanRecord(summary: summary, duplicateCount: duplicateCount,
                                         similarCount: similarCount, lowQualityCount: lowQualityCount) }
    }

    private func _saveScanRecord(summary: LibrarySummary, duplicateCount: Int, similarCount: Int, lowQualityCount: Int) {
        let sql = """
            INSERT INTO scan_records
                (scanned_at,total_count,duplicate_count,similar_count,low_quality_count,freeable_bytes,health_score)
            VALUES (?,?,?,?,?,?,?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logSQLiteError("prepare saveScanRecord")
            return
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(Date().timeIntervalSince1970))
        sqlite3_bind_int(stmt,   2, Int32(summary.totalCount))
        sqlite3_bind_int(stmt,   3, Int32(duplicateCount))
        sqlite3_bind_int(stmt,   4, Int32(similarCount))
        sqlite3_bind_int(stmt,   5, Int32(lowQualityCount))
        sqlite3_bind_int64(stmt, 6, summary.freeableBytes)
        sqlite3_bind_int(stmt,   7, Int32(summary.healthScore))
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            logSQLiteError("step saveScanRecord")
            return
        }
    }

    func loadLatestScanRecord() async -> ScanRecord? {
        await run { self._loadLatestScanRecord() }
    }

    private func _loadLatestScanRecord() -> ScanRecord? {
        let sql = """
            SELECT scanned_at,total_count,duplicate_count,similar_count,
                   low_quality_count,freeable_bytes,health_score
            FROM scan_records ORDER BY scanned_at DESC LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return ScanRecord(
            scannedAt:       Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 0))),
            totalCount:      Int(sqlite3_column_int(stmt, 1)),
            duplicateCount:  Int(sqlite3_column_int(stmt, 2)),
            similarCount:    Int(sqlite3_column_int(stmt, 3)),
            lowQualityCount: Int(sqlite3_column_int(stmt, 4)),
            freeableBytes:   sqlite3_column_int64(stmt, 5),
            healthScore:     Int(sqlite3_column_int(stmt, 6))
        )
    }

    // MARK: - Delete Records

    func saveDeleteRecords(_ assets: [PhotoAsset]) async {
        await run { self._saveDeleteRecords(assets) }
    }

    private func _saveDeleteRecords(_ assets: [PhotoAsset]) {
        guard !assets.isEmpty else { return }
        let sql = "INSERT INTO delete_records (local_id,deleted_at,size_bytes) VALUES (?,?,?)"
        _ = withTransaction("saveDeleteRecords") {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare saveDeleteRecords")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            let now = Int64(Date().timeIntervalSince1970)
            for a in assets {
                sqlite3_bind_text(stmt,  1, a.id,        -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                sqlite3_bind_int64(stmt, 3, a.sizeBytes)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step saveDeleteRecords")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    // MARK: - Asset Scan State

    func loadActiveScannedIds(for ids: [String]) async -> Set<String> {
        await run { self._loadActiveScannedIds(for: ids) }
    }

    private func _loadActiveScannedIds(for ids: [String]) -> Set<String> {
        guard !ids.isEmpty else { return [] }
        let chunkSize = 500
        var offset = 0
        var result = Set<String>()
        while offset < ids.count {
            let chunk = Array(ids[offset..<min(offset + chunkSize, ids.count)])
            let placeholders = chunk.map { _ in "?" }.joined(separator: ",")
            let sql = """
                SELECT local_id
                FROM asset_scan_state
                WHERE is_deleted = 0 AND local_id IN (\(placeholders))
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                for (i, id) in chunk.enumerated() {
                    sqlite3_bind_text(stmt, Int32(i + 1), id, -1, SQLITE_TRANSIENT)
                }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    result.insert(String(cString: sqlite3_column_text(stmt, 0)))
                }
                sqlite3_finalize(stmt)
            }
            offset += chunkSize
        }
        return result
    }

    func markAssetsScanned(_ ids: [String]) async {
        await run { self._markAssetsScanned(ids) }
    }

    private func _markAssetsScanned(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let sql = """
            INSERT INTO asset_scan_state (local_id, first_scanned_at, last_scanned_at, is_deleted, deleted_at)
            VALUES (?, ?, ?, 0, NULL)
            ON CONFLICT(local_id) DO UPDATE SET
                last_scanned_at = excluded.last_scanned_at,
                is_deleted = 0,
                deleted_at = NULL
        """
        _ = withTransaction("markAssetsScanned") {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare markAssetsScanned")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            let now = Int64(Date().timeIntervalSince1970)
            for id in ids {
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                sqlite3_bind_int64(stmt, 3, now)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step markAssetsScanned")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    func markAssetsDeleted(_ ids: [String]) async {
        await run { self._markAssetsDeleted(ids) }
    }

    private func _markAssetsDeleted(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let sql = """
            INSERT INTO asset_scan_state (local_id, first_scanned_at, last_scanned_at, is_deleted, deleted_at)
            VALUES (?, ?, ?, 1, ?)
            ON CONFLICT(local_id) DO UPDATE SET
                is_deleted = 1,
                deleted_at = excluded.deleted_at
        """
        _ = withTransaction("markAssetsDeleted") {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                logSQLiteError("prepare markAssetsDeleted")
                return false
            }
            defer { sqlite3_finalize(stmt) }

            let now = Int64(Date().timeIntervalSince1970)
            for id in ids {
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                sqlite3_bind_int64(stmt, 3, now)
                sqlite3_bind_int64(stmt, 4, now)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    logSQLiteError("step markAssetsDeleted")
                    return false
                }
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
            }
            return true
        }
    }

    // MARK: - Cleaning stats (Settings page)

    struct CleaningStats: Sendable {
        let freedBytes: Int64   // SUM of delete_records.size_bytes
        let scanCount: Int      // number of rows in scan_records
        let healthGain: Int     // latest health_score − first health_score (0 if < 2 scans)

        static let zero = CleaningStats(freedBytes: 0, scanCount: 0, healthGain: 0)
    }

    func loadCleaningStats() async -> CleaningStats {
        await run { self._loadCleaningStats() }
    }

    private func _loadCleaningStats() -> CleaningStats {
        // Total bytes freed across all deletion events
        var freedBytes: Int64 = 0
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COALESCE(SUM(size_bytes),0) FROM delete_records", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { freedBytes = sqlite3_column_int64(stmt, 0) }
            sqlite3_finalize(stmt)
        }

        // Number of complete scan sessions
        var scanCount = 0
        stmt = nil
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM scan_records", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { scanCount = Int(sqlite3_column_int(stmt, 0)) }
            sqlite3_finalize(stmt)
        }

        // Health gain = most-recent score − earliest score (requires ≥ 2 scans)
        var healthGain = 0
        if scanCount >= 2 {
            var first = 0, last = 0
            stmt = nil
            if sqlite3_prepare_v2(db, "SELECT health_score FROM scan_records ORDER BY scanned_at ASC  LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW { first = Int(sqlite3_column_int(stmt, 0)) }
                sqlite3_finalize(stmt)
            }
            stmt = nil
            if sqlite3_prepare_v2(db, "SELECT health_score FROM scan_records ORDER BY scanned_at DESC LIMIT 1", -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW { last = Int(sqlite3_column_int(stmt, 0)) }
                sqlite3_finalize(stmt)
            }
            healthGain = last - first
        }

        return CleaningStats(freedBytes: freedBytes, scanCount: scanCount, healthGain: healthGain)
    }

    // MARK: - Maintenance

    /// Deletes cached scores for assets that no longer exist in the photo library.
    func pruneStaleScores(keepIds: Set<String>) async {
        await run { self._pruneStaleScores(keepIds: keepIds) }
    }

    private func _pruneStaleScores(keepIds: Set<String>) {
        let sql = "SELECT local_id FROM photo_scores"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        var stale: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(stmt, 0))
            if !keepIds.contains(id) { stale.append(id) }
        }
        sqlite3_finalize(stmt)
        _removeScores(for: stale)   // already on queue — call private sync version directly
    }

    // MARK: - Helpers

    @discardableResult
    private func withTransaction(_ context: String, _ work: () -> Bool) -> Bool {
        guard exec("BEGIN") == SQLITE_OK else { return false }
        let ok = work()
        _ = exec(ok ? "COMMIT" : "ROLLBACK")
        if !ok {
            print("[DatabaseService] transaction rolled back: \(context)")
        }
        return ok
    }

    private func logSQLiteError(_ context: String) {
        guard let db else {
            print("[DatabaseService] \(context) failed: database is nil")
            return
        }
        let code = sqlite3_errcode(db)
        let message = String(cString: sqlite3_errmsg(db))
        print("[DatabaseService] \(context) failed (\(code)): \(message)")
    }

    @discardableResult
    private func exec(_ sql: String) -> Int32 {
        guard let db else {
            print("[DatabaseService] exec failed: database is nil")
            return SQLITE_MISUSE
        }
        let rc = sqlite3_exec(db, sql, nil, nil, nil)
        if rc != SQLITE_OK {
            let snippet = sql.replacingOccurrences(of: "\n", with: " ").prefix(80)
            logSQLiteError("exec \(snippet)")
        }
        return rc
    }
}
