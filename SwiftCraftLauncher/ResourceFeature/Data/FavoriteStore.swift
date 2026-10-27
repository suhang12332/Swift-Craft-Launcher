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
/// serial queue; the in-memory map is main-actor isolated so SwiftUI
/// observations remain responsive.
@MainActor
@Observable
final class FavoriteStore {
    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.favorites
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
        favoriteIds[type, default: []].insert(id)
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
        favoriteIds[type]?.remove(id)
    }

    /// Checks whether a project is favorited for a given type using the in-memory map.
    func isFavorite(id: String, type: String) -> Bool {
        try? ensureInitialized()
        return favoriteIds[type]?.contains(id) ?? false
    }

    /// Returns one page of favorite IDs for a type and data source.
    ///
    /// IDs are ordered ascending and paged with a keyset cursor (`after`), so
    /// removing a favorite cannot shift the next page and cause skipped or
    /// duplicated entries.
    /// - Parameters:
    ///   - type: The resource type (for example `mod`).
    ///   - dataSource: The provider whose project IDs should be returned.
    ///   - after: The last ID of the previously loaded page, or `nil` for the
    ///     first page.
    ///   - limit: The maximum number of IDs to return.
    /// - Returns: The next page of favorite IDs, ordered ascending.
    func favoriteIdsPage(
        type: String,
        dataSource: DataSource,
        after: String?,
        limit: Int,
    ) -> [String] {
        guard limit > 0 else { return [] }
        try? ensureInitialized()

        let sourceFilter = dataSource == .curseforge
            ? "substr(id, 1, 3) = 'cf-'"
            : "substr(id, 1, 3) <> 'cf-'"
        let afterClause = after == nil ? "" : "AND id > ?"
        let sql = """
        SELECT id FROM \(tableName)
        WHERE type = ? AND \(sourceFilter) \(afterClause)
        ORDER BY id ASC
        LIMIT ?;
        """

        do {
            return try withPreparedStatement(sql) { statement in
                var index: Int32 = 1
                SQLiteDatabase.bind(statement, index: index, value: type)
                index += 1
                if let after {
                    SQLiteDatabase.bind(statement, index: index, value: after)
                    index += 1
                }
                SQLiteDatabase.bind(statement, index: index, value: limit)

                var ids: [String] = []
                ids.reserveCapacity(limit)
                while sqlite3_step(statement) == SQLITE_ROW {
                    if let id = SQLiteDatabase.stringColumn(statement, index: 0) {
                        ids.append(id)
                    }
                }
                return ids
            }
        } catch {
            return []
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
        favoriteIds = map
    }

    private func ensureInitialized() throws {
        guard !isInitialized else { return }
        try FileManager.default.createDirectory(
            at: AppPaths.dataDirectory,
            withIntermediateDirectories: true,
        )
        try db.open()
        try db.execute(createTableSQL)
        try? db.execute(
            "DROP INDEX IF EXISTS idx_favorites_type;",
        )
        try? db.execute(
            "CREATE INDEX IF NOT EXISTS idx_favorites_type_id ON \(tableName)(type, id);",
        )
        isInitialized = true
        loadAllIds()
    }

    private func withPreparedStatement<T>(
        _ sql: String,
        _ body: (OpaquePointer) throws -> T,
    ) throws -> T {
        try db.withStatement(sql, body)
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
