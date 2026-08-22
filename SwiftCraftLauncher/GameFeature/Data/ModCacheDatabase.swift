//
//  ModCacheDatabase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SQLite3

/// Provides SQLite storage for mod metadata caches.
///
/// Stores parsed `mod.json` payloads keyed by file hash, enabling fast
/// lookups without re-parsing jar files.
class ModCacheDatabase {
    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.modCache
    private var isInitialized = false

    private let createTableSQL: String
    private let upsertSQL: String
    private let selectSQL: String
    private let selectAllSQL: String
    private let deleteByHashSQL: String

    /// A lightweight view of a cached mod detail used to inspect its `team` marker.
    private struct CachedModTeam: Decodable {
        let team: String?
    }

    /// Creates a mod cache database.
    ///
    /// - Parameter dbPath: The file path for the SQLite database.
    init(dbPath: String) {
        db = SQLiteDatabase.database(at: dbPath)
        createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            hash TEXT PRIMARY KEY,
            json_data BLOB NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        upsertSQL = """
        INSERT OR REPLACE INTO \(tableName)
        (hash, json_data, created_at, updated_at)
        VALUES (?, ?,
            COALESCE((SELECT created_at FROM \(tableName) WHERE hash = ?), ?),
            ?)
        """
        selectSQL = "SELECT json_data FROM \(tableName) WHERE hash = ? LIMIT 1"
        selectAllSQL = "SELECT hash, json_data FROM \(tableName)"
        deleteByHashSQL = "DELETE FROM \(tableName) WHERE hash = ?"
    }

    /// Opens the database connection and creates the table if needed.
    func open() throws {
        if isInitialized {
            return
        }
        try db.open()
        try createTable()
        isInitialized = true
    }

    private func createTable() throws {
        try db.execute(createTableSQL)
        try? db.execute(
            "CREATE INDEX IF NOT EXISTS idx_mod_cache_updated_at ON \(tableName)(updated_at);",
        )
        AppLog.game.debug("Mod cache table created or already exists")
    }

    /// Stores mod metadata in the cache.
    /// - Parameters:
    ///   - hash: The hash of the mod file.
    ///   - jsonData: The raw JSON bytes to cache.
    func saveModCache(hash: String, jsonData: Data) throws {
        try db.transaction {
            let now = Date()
            try withPreparedStatement(upsertSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: hash)
                SQLiteDatabase.bind(statement, index: 2, data: jsonData)
                SQLiteDatabase.bind(statement, index: 3, value: hash)
                SQLiteDatabase.bind(statement, index: 4, value: now)
                SQLiteDatabase.bind(statement, index: 5, value: now)
                try stepStatement(statement)
            }
        }
    }

    /// Stores multiple mod cache entries within a single transaction.
    /// - Parameter data: A dictionary mapping file hashes to JSON data.
    func saveModCaches(_ data: [String: Data]) throws {
        try db.transaction {
            let now = Date()
            try withPreparedStatement(upsertSQL) { statement in
                for (hash, jsonData) in data {
                    sqlite3_reset(statement)
                    SQLiteDatabase.bind(statement, index: 1, value: hash)
                    SQLiteDatabase.bind(statement, index: 2, data: jsonData)
                    SQLiteDatabase.bind(statement, index: 3, value: hash)
                    SQLiteDatabase.bind(statement, index: 4, value: now)
                    SQLiteDatabase.bind(statement, index: 5, value: now)
                    try stepStatement(statement)
                }
            }
        }
    }

    /// Retrieves cached mod data for the specified hash.
    /// - Parameter hash: The hash of the mod file.
    /// - Returns: The raw JSON data, or `nil` if no cached entry exists.
    func getModCache(hash: String) throws -> Data? {
        var result: Data?
        try withPreparedStatement(selectSQL) { statement in
            SQLiteDatabase.bind(statement, index: 1, value: hash)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let data = SQLiteDatabase.dataColumn(statement, index: 0) else {
                return
            }
            result = data
        }
        return result
    }

    /// Removes cached mod entries whose metadata marks them as local-only fallbacks.
    func clearLocalModCaches() throws {
        var localHashes: [String] = []
        try withPreparedStatement(selectAllSQL) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let hash = SQLiteDatabase.stringColumn(statement, index: 0),
                      let data = SQLiteDatabase.dataColumn(statement, index: 1),
                      let cached = try? JSONDecoder().decode(CachedModTeam.self, from: data),
                      cached.team == "local"
                else { continue }
                localHashes.append(hash)
            }
        }

        guard !localHashes.isEmpty else { return }
        try db.transaction {
            try withPreparedStatement(deleteByHashSQL) { statement in
                for hash in localHashes {
                    sqlite3_reset(statement)
                    SQLiteDatabase.bind(statement, index: 1, value: hash)
                    try stepStatement(statement)
                }
            }
        }
    }

    private func withPreparedStatement<T>(
        _ sql: String,
        _ body: (OpaquePointer) throws -> T,
    ) throws -> T {
        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func stepStatement(_ statement: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db.database))
            throw GlobalError.validation(
                i18nKey: "error.validation.sql_execution_failed",
                level: .notification,
                message: "SQLite step failed, expected SQLITE_DONE. Error: \(errorMessage)",
            )
        }
    }
}
