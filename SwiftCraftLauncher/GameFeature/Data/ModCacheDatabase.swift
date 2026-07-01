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

    /// Creates a mod cache database.
    ///
    /// - Parameter dbPath: The file path for the SQLite database.
    init(dbPath: String) {
        db = SQLiteDatabase(path: dbPath)
    }

    /// Opens the database connection and creates the table if needed.
    func open() throws {
        try db.open()
        try createTable()
    }

    private func createTable() throws {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            hash TEXT PRIMARY KEY,
            json_data BLOB NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """

        try db.execute(createTableSQL)

        let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_mod_cache_updated_at ON \(tableName)(updated_at);
        """
        try? db.execute(createIndexSQL)

        AppLog.game.debug("Mod cache table created or already exists")
    }

    /// Closes the database connection.
    func close() {
        db.close()
    }

    /// Saves a mod cache entry.
    ///
    /// - Parameters:
    ///   - hash: The hash of the mod file.
    ///   - jsonData: The raw JSON data of the mod metadata.
    func saveModCache(hash: String, jsonData: Data) throws {
        try db.transaction {
            let now = Date()
            let sql = """
            INSERT OR REPLACE INTO \(tableName)
            (hash, json_data, created_at, updated_at)
            VALUES (?, ?,
                COALESCE((SELECT created_at FROM \(tableName) WHERE hash = ?), ?),
                ?)
            """

            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: hash)
            SQLiteDatabase.bind(statement, index: 2, data: jsonData)
            SQLiteDatabase.bind(statement, index: 3, value: hash)
            SQLiteDatabase.bind(statement, index: 4, value: now)
            SQLiteDatabase.bind(statement, index: 5, value: now)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    i18nKey: "error.validation.mod_cache_save_failed",
                    level: .notification,
                )
            }
        }
    }

    /// Saves multiple mod cache entries within a single transaction.
    ///
    /// - Parameter data: A dictionary mapping file hashes to JSON data.
    func saveModCaches(_ data: [String: Data]) throws {
        try db.transaction {
            let now = Date()
            let sql = """
            INSERT OR REPLACE INTO \(tableName)
            (hash, json_data, created_at, updated_at)
            VALUES (?, ?,
                COALESCE((SELECT created_at FROM \(tableName) WHERE hash = ?), ?),
                ?)
            """

            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            for (hash, jsonData) in data {
                sqlite3_reset(statement)
                SQLiteDatabase.bind(statement, index: 1, value: hash)
                SQLiteDatabase.bind(statement, index: 2, data: jsonData)
                SQLiteDatabase.bind(statement, index: 3, value: hash)
                SQLiteDatabase.bind(statement, index: 4, value: now)
                SQLiteDatabase.bind(statement, index: 5, value: now)

                let result = sqlite3_step(statement)
                guard result == SQLITE_DONE else {
                    let errorMessage = String(cString: sqlite3_errmsg(db.database))
                    throw GlobalError.validation(
                        i18nKey: "error.validation.mod_cache_batch_save_failed",
                        level: .notification,
                    )
                }
            }
        }
    }

    /// Retrieves cached mod data for the specified hash.
    ///
    /// - Parameter hash: The hash of the mod file.
    /// - Returns: The raw JSON data, or `nil` if no cached entry exists.
    func getModCache(hash: String) throws -> Data? {
        let sql = "SELECT json_data FROM \(tableName) WHERE hash = ? LIMIT 1"

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        SQLiteDatabase.bind(statement, index: 1, value: hash)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let jsonData = SQLiteDatabase.dataColumn(statement, index: 0) else {
            return nil
        }

        return jsonData
    }

    /// Removes all cached mod entries from the database.
    func clearAllModCaches() throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName)"
            try db.execute(sql)
        }
    }
}
