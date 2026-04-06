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
        // Migration: add has_faces column to existing installs (ignored if already present)
        sqlite3_exec(db, "ALTER TABLE photo_scores ADD COLUMN has_faces INTEGER NOT NULL DEFAULT 0", nil, nil, nil)
        // Migration: persist real file size to avoid fallback estimates on next launch
        sqlite3_exec(db, "ALTER TABLE photo_scores ADD COLUMN file_size_bytes INTEGER", nil, nil, nil)
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
        """, nil, nil, nil)
    }

    // MARK: - Queue helper

    /// Dispatches `work` onto the serial queue and suspends the caller until it finishes.
    /// Use this for every public method so SQLite I/O never touches the cooperative pool.
    private func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { cont in
            queue.async { cont.resume(returning: work()) }
        }
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
        exec("BEGIN")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
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
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
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
        exec("BEGIN")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for e in entries {
                sqlite3_bind_int64(stmt, 1, e.fileSizeBytes)
                sqlite3_bind_text(stmt,  2, e.localId, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
    }

    func removeScores(for ids: [String]) async {
        await run { self._removeScores(for: ids) }
    }

    private func _removeScores(for ids: [String]) {
        guard !ids.isEmpty else { return }
        exec("BEGIN")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "DELETE FROM photo_scores WHERE local_id=?", -1, &stmt, nil) == SQLITE_OK {
            for id in ids {
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
    }

    // MARK: - Photo Groups (duplicate / similar)

    func saveGroups(_ groups: [PhotoGroup]) async {
        await run { self._saveGroups(groups) }
    }

    private func _saveGroups(_ groups: [PhotoGroup]) {
        exec("DELETE FROM photo_groups")
        guard !groups.isEmpty else { return }
        let sql = "INSERT OR IGNORE INTO photo_groups (group_id,local_id,group_type,rank) VALUES (?,?,?,?)"
        exec("BEGIN")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for g in groups {
                let gid   = g.id.uuidString
                let gtype = g.groupType == .duplicate ? "duplicate" : "similar"
                for (rank, asset) in g.assets.enumerated() {
                    sqlite3_bind_text(stmt, 1, gid,      -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 2, asset.id, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(stmt, 3, gtype,    -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(stmt,  4, Int32(rank))
                    sqlite3_step(stmt)
                    sqlite3_reset(stmt)
                }
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
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
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, Int64(Date().timeIntervalSince1970))
            sqlite3_bind_int(stmt,   2, Int32(summary.totalCount))
            sqlite3_bind_int(stmt,   3, Int32(duplicateCount))
            sqlite3_bind_int(stmt,   4, Int32(similarCount))
            sqlite3_bind_int(stmt,   5, Int32(lowQualityCount))
            sqlite3_bind_int64(stmt, 6, summary.freeableBytes)
            sqlite3_bind_int(stmt,   7, Int32(summary.healthScore))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
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
        exec("BEGIN")
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let now = Int64(Date().timeIntervalSince1970)
            for a in assets {
                sqlite3_bind_text(stmt,  1, a.id,        -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 2, now)
                sqlite3_bind_int64(stmt, 3, a.sizeBytes)
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
            sqlite3_finalize(stmt)
        }
        exec("COMMIT")
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

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}
