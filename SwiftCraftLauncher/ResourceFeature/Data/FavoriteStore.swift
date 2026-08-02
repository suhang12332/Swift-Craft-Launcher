//
//  FavoriteStore.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation
import SQLite3

/// Manages a local SQLite-backed collection of favorited Modrinth projects.
///
/// Maintains an in-memory map `[type: Set<id>]` that is kept in sync with the
/// database. Database thread safety is handled by `SQLiteDatabase`'s internal
/// serial queue. The in-memory map is updated on the main thread so SwiftUI
/// observations remain responsive.
@Observable
final class FavoriteStore: @unchecked Sendable {
    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.favorites
    private let initQueue = DispatchQueue(label: "com.swiftcraftlauncher.favoritestore.init")
    private var isInitialized = false

    private let createTableSQL: String
    private let insertSQL: String
    private let deleteSQL: String
    private let selectAllIdsByTypeSQL: String

    /// All favorite project IDs grouped by type, kept in sync with the database.
    var favoriteIds: [String: Set<String>] = [:]

    init() {
        db = SQLiteDatabase.database(at: AppPaths.gameVersionDatabase.path)
        createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            id TEXT NOT NULL,
            type TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY (id, type)
        );
        """
        insertSQL = """
        INSERT OR REPLACE INTO \(tableName)
        (id, type, created_at, updated_at)
        VALUES (?, ?,
            COALESCE((SELECT created_at FROM \(tableName) WHERE id = ? AND type = ?), ?),
            ?)
        """
        deleteSQL = "DELETE FROM \(tableName) WHERE id = ? AND type = ?"
        selectAllIdsByTypeSQL = "SELECT id, type FROM \(tableName)"
    }

    /// Adds a favorite entry and updates the in-memory map.
    func addFavorite(id: String, type: String) throws {
        try ensureInitialized()
        let now = Date()
        try db.transaction {
            try withPreparedStatement(insertSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: id)
                SQLiteDatabase.bind(statement, index: 2, value: type)
                SQLiteDatabase.bind(statement, index: 3, value: id)
                SQLiteDatabase.bind(statement, index: 4, value: type)
                SQLiteDatabase.bind(statement, index: 5, value: now)
                SQLiteDatabase.bind(statement, index: 6, value: now)
                try stepStatement(statement)
            }
        }
        DispatchQueue.main.async { [self] in
            favoriteIds[type, default: []].insert(id)
        }
    }

    /// Removes a favorite entry for a specific type and updates the in-memory map.
    func removeFavorite(id: String, type: String) throws {
        try ensureInitialized()
        try db.transaction {
            try withPreparedStatement(deleteSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: id)
                SQLiteDatabase.bind(statement, index: 2, value: type)
                try stepStatement(statement)
            }
        }
        DispatchQueue.main.async { [self] in
            favoriteIds[type]?.remove(id)
        }
    }

    /// Checks whether a project is favorited for a given type using the in-memory map.
    func isFavorite(id: String, type: String) -> Bool {
        try? ensureInitialized()
        return favoriteIds[type]?.contains(id) ?? false
    }

    /// Removes all favorite entries and clears the in-memory map.
    func clearAll() throws {
        try ensureInitialized()
        try db.transaction {
            try db.execute("DELETE FROM \(tableName)")
        }
        DispatchQueue.main.async { [self] in
            favoriteIds.removeAll()
        }
    }

    private func loadAllIds() {
        guard isInitialized else { return }
        let pairs: [(id: String, type: String)]
        do {
            pairs = try withPreparedStatement(selectAllIdsByTypeSQL) { statement -> [(String, String)] in
                var result: [(String, String)] = []
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let id = SQLiteDatabase.stringColumn(statement, index: 0),
                       let type = SQLiteDatabase.stringColumn(statement, index: 1) {
                        result.append((id, type))
                    }
                }
                return result
            }
        } catch {
            return
        }
        var map: [String: Set<String>] = [:]
        for (id, type) in pairs {
            map[type, default: []].insert(id)
        }
        DispatchQueue.main.async { [self] in
            favoriteIds = map
        }
    }

    private func ensureInitialized() throws {
        try initQueue.sync {
            guard !isInitialized else { return }
            try FileManager.default.createDirectory(
                at: AppPaths.dataDirectory,
                withIntermediateDirectories: true,
            )
            try db.open()
            try db.execute(createTableSQL)
            try? db.execute(
                "CREATE INDEX IF NOT EXISTS idx_favorites_type ON \(tableName)(type);",
            )
            isInitialized = true
            loadAllIds()
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
