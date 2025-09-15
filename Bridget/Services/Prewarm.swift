// Sources/Prewarm.swift
// Step 5: Prewarm & cold-start resiliency using SQLite persistence
// This file is self-contained and additive. Wire actual project types where indicated.

import Foundation
import SQLite3

// SQLite transient destructor helper for bind_text
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Type Adapters (convert between your project types and SQLite storage)

/// Adapter to convert between your MatrixKey and SQLite storage format
public struct MatrixKeyAdapter {
    /// Convert your MatrixKey to SQLite storage key
    internal static func toStorageKey(_ key: MatrixKey) -> String {
        let source = key.source.rawValue.lowercased()
        let target = key.target.rawValue.lowercased()
        let bridge = (key.bridgeId ?? "-")
        return "\(source)->\(target)|\(bridge)|v=\(key.version)"
    }
    
    /// Convert from SQLite storage key back to MatrixKey
    internal static func fromStorageKey(_ storageKey: String, source: CoordinateSystem, target: CoordinateSystem, bridgeId: String?, version: Int) -> MatrixKey {
        return MatrixKey(source: source, target: target, bridgeId: bridgeId, version: version)
    }
}

/// Adapter to convert between your TransformationMatrix and SQLite storage format
public struct TransformationMatrixAdapter {
    /// Convert your TransformationMatrix to SQLite storage format (3x3 row-major)
    public static func toStorageFormat(_ matrix: TransformationMatrix) -> (m00: Double, m01: Double, m02: Double, m10: Double, m11: Double, m12: Double, m20: Double, m21: Double, m22: Double) {
        // Convert from your affine format to 3x3 matrix
        let cosRot = cos(matrix.rotation * .pi / 180.0)
        let sinRot = sin(matrix.rotation * .pi / 180.0)
        
        return (
            m00: matrix.latScale * cosRot, m01: -matrix.latScale * sinRot, m02: matrix.latOffset,
            m10: matrix.lonScale * sinRot, m11: matrix.lonScale * cosRot,  m12: matrix.lonOffset,
            m20: 0.0,                     m21: 0.0,                      m22: 1.0
        )
    }
    
    /// Convert from SQLite storage format back to your TransformationMatrix
    public static func fromStorageFormat(_ m00: Double, _ m01: Double, _ m02: Double, _ m10: Double, _ m11: Double, _ m12: Double, _ m20: Double, _ m21: Double, _ m22: Double) -> TransformationMatrix {
        // Extract rotation from matrix elements
        // For the rotation matrix: [cos -sin] we can extract rotation as atan2(-m01, m00) if scales are equal
        // But since scales might differ, we need a more robust approach
        let rotation = atan2(-m01, m00) * 180.0 / .pi
        
        // Extract scales (these should be consistent)
        let latScale = sqrt(m00 * m00 + m01 * m01)
        let lonScale = sqrt(m10 * m10 + m11 * m11)
        
        return TransformationMatrix(
            latOffset: m02,
            lonOffset: m12,
            latScale: latScale,
            lonScale: lonScale,
            rotation: rotation
        )
    }
}

public struct TransformFlags {
    public var caching: Bool = true
    public var pointCache: Bool = false
    public var batch: Bool = false
    public var multiSource: Bool = false
    public var strictGuardrails: Bool = true
    // Disk persistence for matrices
    public var diskPersistence: Bool = true // maps transform.cache.disk.enabled
}

// MARK: - SQLite-backed matrix store

public final class MatrixStoreSQLite {
    public enum StoreError: Error { case openFailed, execFailed(String), prepareFailed, stepFailed, notFound }

    private var db: OpaquePointer?
    private let path: String

    // Schema:
    // matrices(key TEXT PRIMARY KEY, source TEXT, target TEXT, bridgeId TEXT NULL, version TEXT,
    //          m00 REAL, m01 REAL, m02 REAL, m10 REAL, m11 REAL, m12 REAL, m20 REAL, m21 REAL, m22 REAL,
    //          lastUsedAt REAL, useCount INTEGER)
    public init(path: String) throws {
        self.path = path
        try open()
        try ensureSchema()
    }

    deinit { if db != nil { sqlite3_close(db) } }

    private func open() throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw StoreError.openFailed
        }
        // Pragmas for small, local, read-mostly DB
        _ = exec("PRAGMA journal_mode=WAL;")
        _ = exec("PRAGMA synchronous=NORMAL;")
        _ = exec("PRAGMA temp_store=MEMORY;")
    }

    private func ensureSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS matrices (
            key TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            target TEXT NOT NULL,
            bridgeId TEXT,
            version TEXT NOT NULL,
            m00 REAL NOT NULL, m01 REAL NOT NULL, m02 REAL NOT NULL,
            m10 REAL NOT NULL, m11 REAL NOT NULL, m12 REAL NOT NULL,
            m20 REAL NOT NULL, m21 REAL NOT NULL, m22 REAL NOT NULL,
            lastUsedAt REAL NOT NULL DEFAULT (strftime('%s','now')),
            useCount INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_matrices_use ON matrices(useCount DESC, lastUsedAt DESC);
        """
        guard exec(sql) == SQLITE_OK else { throw StoreError.execFailed("schema") }
    }

    @discardableResult
    private func exec(_ sql: String) -> Int32 {
        var err: UnsafeMutablePointer<Int8>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK, let cmsg = err { sqlite3_free(cmsg) }
        return rc
    }

    private func makeKey(_ key: MatrixKey) -> String {
        // stable composite key using your MatrixKey structure
        return MatrixKeyAdapter.toStorageKey(key)
    }

    // Upsert a matrix and bump stats
    internal func upsert(key: MatrixKey, matrix: TransformationMatrix, now: TimeInterval = Date().timeIntervalSince1970) throws {
        let sql = """
        INSERT INTO matrices (key, source, target, bridgeId, version,
                              m00, m01, m02, m10, m11, m12, m20, m21, m22,
                              lastUsedAt, useCount)
        VALUES (?,?,?,?,?, ?,?,?,?,?, ?,?,?,?, ?,?)
        ON CONFLICT(key) DO UPDATE SET
            m00=excluded.m00, m01=excluded.m01, m02=excluded.m02,
            m10=excluded.m10, m11=excluded.m11, m12=excluded.m12,
            m20=excluded.m20, m21=excluded.m21, m22=excluded.m22,
            lastUsedAt=excluded.lastUsedAt,
            useCount=matrices.useCount + 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.prepareFailed }
        defer { sqlite3_finalize(stmt) }

        let k = makeKey(key)
        let matrixElements = TransformationMatrixAdapter.toStorageFormat(matrix)
        
        sqlite3_bind_text(stmt, 1, k, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, key.source.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, key.target.rawValue, -1, SQLITE_TRANSIENT)
        if let b = key.bridgeId { sqlite3_bind_text(stmt, 4, b, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, 4) }
        sqlite3_bind_int64(stmt, 5, Int64(key.version))
        sqlite3_bind_double(stmt, 6,  matrixElements.m00); sqlite3_bind_double(stmt, 7,  matrixElements.m01); sqlite3_bind_double(stmt, 8,  matrixElements.m02)
        sqlite3_bind_double(stmt, 9,  matrixElements.m10); sqlite3_bind_double(stmt, 10, matrixElements.m11); sqlite3_bind_double(stmt, 11, matrixElements.m12)
        sqlite3_bind_double(stmt, 12, matrixElements.m20); sqlite3_bind_double(stmt, 13, matrixElements.m21); sqlite3_bind_double(stmt, 14, matrixElements.m22)
        sqlite3_bind_double(stmt, 15, now)
        sqlite3_bind_int64(stmt, 16, 1)

        guard sqlite3_step(stmt) == SQLITE_DONE else { throw StoreError.stepFailed }
    }

    // Retrieve a matrix by key and bump stats
    internal func load(key: MatrixKey, now: TimeInterval = Date().timeIntervalSince1970) throws -> TransformationMatrix {
        let sql = "SELECT m00,m01,m02,m10,m11,m12,m20,m21,m22 FROM matrices WHERE key = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.prepareFailed }
        defer { sqlite3_finalize(stmt) }

        let k = makeKey(key)
        sqlite3_bind_text(stmt, 1, k, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            let m = TransformationMatrixAdapter.fromStorageFormat(
                sqlite3_column_double(stmt, 0), sqlite3_column_double(stmt, 1), sqlite3_column_double(stmt, 2),
                sqlite3_column_double(stmt, 3), sqlite3_column_double(stmt, 4), sqlite3_column_double(stmt, 5),
                sqlite3_column_double(stmt, 6), sqlite3_column_double(stmt, 7), sqlite3_column_double(stmt, 8)
            )
            // bump stats async (fire-and-forget)
            _ = exec("UPDATE matrices SET lastUsedAt=\(now), useCount=useCount+1 WHERE key='\(k.replacingOccurrences(of: "'", with: "''"))';")
            return m
        }
        throw StoreError.notFound
    }

    // Top-N by useCount/lastUsedAt for prewarm
    internal func topN(_ n: Int) throws -> [(MatrixKey, TransformationMatrix)] {
        let sql = """
        SELECT key, source, target, bridgeId, version,
               m00,m01,m02,m10,m11,m12,m20,m21,m22
        FROM matrices
        ORDER BY useCount DESC, lastUsedAt DESC
        LIMIT ?;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw StoreError.prepareFailed }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(n))

        var out: [(MatrixKey, TransformationMatrix)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let sourceStr = String(cString: sqlite3_column_text(stmt, 1))
            let targetStr = String(cString: sqlite3_column_text(stmt, 2))
            let bridgePtr = sqlite3_column_text(stmt, 3)
            let bridge = bridgePtr != nil ? String(cString: bridgePtr!) : nil
            let version = Int(sqlite3_column_int64(stmt, 4))
            
            // Convert string coordinates back to enum
            guard let source = CoordinateSystem(rawValue: sourceStr),
                  let target = CoordinateSystem(rawValue: targetStr) else { continue }
            
            let key = MatrixKey(source: source, target: target, bridgeId: bridge, version: version)
            let m = TransformationMatrixAdapter.fromStorageFormat(
                sqlite3_column_double(stmt, 5), sqlite3_column_double(stmt, 6), sqlite3_column_double(stmt, 7),
                sqlite3_column_double(stmt, 8), sqlite3_column_double(stmt, 9), sqlite3_column_double(stmt, 10),
                sqlite3_column_double(stmt, 11), sqlite3_column_double(stmt, 12), sqlite3_column_double(stmt, 13)
            )
            out.append((key, m))
        }
        return out
    }

}

// MARK: - Prewarmer

internal enum Prewarmer {
    internal struct Result: Codable, Equatable {
        public var attempted: Int
        public var loaded: Int
        public var durationSeconds: Double
    }

    // Provide closures to integrate with your existing cache/matrix types without import cycles.
    // - loadMatrix: how to fetch a matrix if not in DB (optional)
    // - cacheSet: how to insert matrix into in-memory cache (e.g., SimpleLRU)
    internal static func prewarm(atStartup flags: TransformFlags,
                               dbPath: String,
                               topN: Int = 32,
                               loadMatrix: ((MatrixKey) throws -> TransformationMatrix)? = nil,
                               cacheSet: @escaping (MatrixKey, TransformationMatrix) -> Void) -> Result {
        print("Prewarmer.prewarm called with flags: caching=\(flags.caching), diskPersistence=\(flags.diskPersistence)")
        let t0 = CFAbsoluteTimeGetCurrent()
        var attempted = 0
        var loaded = 0

        guard flags.caching, flags.diskPersistence else {
            print("Prewarm skipped - flags not enabled")
            return Result(attempted: 0, loaded: 0, durationSeconds: CFAbsoluteTimeGetCurrent() - t0)
        }

        do {
            print("Creating MatrixStoreSQLite with path: \(dbPath)")
            let store = try MatrixStoreSQLite(path: dbPath)
            print("Store created successfully, calling topN(\(topN))")
            let pairs = try store.topN(topN)
            print("topN returned \(pairs.count) pairs")
            attempted = pairs.count
            for (key, matrix) in pairs {
                print("Calling cacheSet for key: \(key.bridgeId ?? "nil")")
                cacheSet(key, matrix)
                loaded += 1
            }
            // Optionally backfill from source for popular-but-missing keys
            if loaded < topN, let loader = loadMatrix {
                // No-op here; caller may decide which keys to backfill (e.g., config favorites)
                _ = loader // keep closure alive; documented extension point
            }
        } catch {
            print("Prewarm error: \(error)")
            // Swallow errors on startup to avoid crash loops; rely on metrics/logging externally
            attempted = 0; loaded = 0
        }

        let duration = CFAbsoluteTimeGetCurrent() - t0
        print("Prewarm completed: attempted=\(attempted), loaded=\(loaded), duration=\(duration)")
        return Result(attempted: attempted, loaded: loaded, durationSeconds: duration)
    }
}

// MARK: - Convenience helpers

public enum PrewarmPaths {
    // Default location: Library/Application Support/TransformMatrices/matrices.sqlite3
    public static func defaultDBPath(appName: String = Bundle.main.bundleIdentifier ?? "App") -> String {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("TransformMatrices", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("matrices.sqlite3").path
    }
}

