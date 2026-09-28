//
//  SkinLibraryStore.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SQLite3

/// Manages a local SQLite-backed skin library.
///
/// The library stores metadata about imported skin files and tracks their
/// usage history. Skin image files are cached on disk, and the database
/// records are automatically cleaned up when the corresponding file is missing.
final class SkinLibraryStore {
    private let fileManager: FileManager
    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.skinLibrary
    private var isInitialized = false

    private let selectColumns = "original_file_name, sha1, model, last_used_at"
    private let createTableSQL: String
    private let upsertSQL: String
    private let deleteSQL: String
    private let selectAllSQL: String

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        db = SQLiteDatabase.database(at: AppPaths.gameVersionDatabase.path)
        createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(AppConstants.DatabaseTables.skinLibrary) (
            original_file_name TEXT NOT NULL,
            sha1 TEXT NOT NULL PRIMARY KEY,
            model TEXT NOT NULL,
            last_used_at REAL NOT NULL
        );
        """
        upsertSQL = """
        INSERT OR REPLACE INTO \(AppConstants.DatabaseTables.skinLibrary)
        (original_file_name, sha1, model, last_used_at)
        VALUES (?, ?, ?, ?)
        """
        deleteSQL = "DELETE FROM \(AppConstants.DatabaseTables.skinLibrary) WHERE sha1 = ?"
        selectAllSQL = """
        SELECT \(selectColumns)
        FROM \(tableName)
        ORDER BY last_used_at DESC
        """
    }

    /// Loads all skin library items, omitting entries whose files are missing.
    func loadItems() throws -> [SkinLibraryItem] {
        try initializeIfNeeded()
        var items: [SkinLibraryItem] = []
        try withPreparedStatement(selectAllSQL) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let item = decodeItem(from: statement) else { continue }
                if fileManager.fileExists(atPath: item.fileURL.path) {
                    items.append(item)
                } else {
                    try? deleteItemRecord(sha1: item.sha1)
                }
            }
        }
        return items
    }

    /// Saves skin data to the library and writes the image file to disk.
    ///
    /// If a file with the same SHA-1 already exists, the existing file is reused.
    ///
    /// - Parameters:
    ///   - data: The raw PNG data of the skin.
    ///   - model: The skin model type.
    ///   - originalFileName: The original file name, used for display purposes.
    /// - Returns: The created library item.
    @discardableResult
    func saveSkin(
        data: Data,
        model: PlayerSkinService.PublicSkinInfo.SkinModel,
        originalFileName: String?,
    ) throws -> SkinLibraryItem {
        try initializeIfNeeded()

        let sha1 = data.sha1
        let libraryFileName = "\(sha1).png"
        let destinationURL = AppPaths.skinsDirectory.appendingPathComponent(libraryFileName)
        let now = Date()

        if !fileManager.fileExists(atPath: destinationURL.path) {
            try data.write(to: destinationURL, options: .atomic)
        }

        let item = SkinLibraryItem(
            originalFileName: normalizedFileName(from: originalFileName),
            sha1: sha1,
            model: model,
            lastUsedAt: now,
        )

        try upsert(item)
        return item
    }

    /// Deletes a skin library item and its associated file.
    ///
    /// - Parameter item: The item to delete.
    func deleteItem(_ item: SkinLibraryItem) throws {
        try initializeIfNeeded()

        if fileManager.fileExists(atPath: item.fileURL.path) {
            try fileManager.removeItem(at: item.fileURL)
        }

        try deleteItemRecord(sha1: item.sha1)
    }

    private func initializeIfNeeded() throws {
        guard !isInitialized else { return }
        try ensureDirectoriesIfNeeded()
        try db.open()
        try migrateTableIfNeeded()
        try createTableIfNeeded()
        try createIndexesIfNeeded()
        isInitialized = true
    }

    private func ensureDirectoriesIfNeeded() throws {
        try fileManager.createDirectory(
            at: AppPaths.skinsDirectory,
            withIntermediateDirectories: true,
            attributes: nil,
        )
    }

    private func createTableIfNeeded() throws {
        try db.execute(createTableSQL)
    }

    private func migrateTableIfNeeded() throws {
        let pragmaSQL = "PRAGMA table_info(\(tableName));"
        let columns = try withPreparedStatement(pragmaSQL) { statement in
            var names = Set<String>()
            while sqlite3_step(statement) == SQLITE_ROW {
                if let columnName = SQLiteDatabase.stringColumn(statement, index: 1) {
                    names.insert(columnName)
                }
            }
            return names
        }

        guard !columns.isEmpty else { return }
        let needsMigration = columns.contains("id") || columns.contains("created_at") || columns.contains("file_name")
        guard needsMigration else { return }

        try db.transaction {
            let tempTable = "\(tableName)_new"
            try db.execute("""
            CREATE TABLE IF NOT EXISTS \(tempTable) (
                original_file_name TEXT NOT NULL,
                sha1 TEXT NOT NULL PRIMARY KEY,
                model TEXT NOT NULL,
                last_used_at REAL NOT NULL
            );
            """)
            try db.execute("""
            INSERT OR REPLACE INTO \(tempTable) (original_file_name, sha1, model, last_used_at)
            SELECT original_file_name, sha1, model, last_used_at
            FROM \(tableName);
            """)
            try db.execute("DROP TABLE \(tableName);")
            try db.execute("ALTER TABLE \(tempTable) RENAME TO \(tableName);")
        }
    }

    private func createIndexesIfNeeded() throws {
        try? db.execute(
            "CREATE INDEX IF NOT EXISTS idx_skin_library_last_used_at ON \(tableName)(last_used_at DESC);",
        )
        try? db.execute(
            "CREATE INDEX IF NOT EXISTS idx_skin_library_sha1 ON \(tableName)(sha1);",
        )
    }

    private func upsert(_ item: SkinLibraryItem) throws {
        try db.transaction {
            try withPreparedStatement(upsertSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: item.originalFileName)
                SQLiteDatabase.bind(statement, index: 2, value: item.sha1)
                SQLiteDatabase.bind(statement, index: 3, value: item.model.rawValue)
                SQLiteDatabase.bind(statement, index: 4, value: item.lastUsedAt)
                try stepStatement(statement)
            }
        }
    }

    private func deleteItemRecord(sha1: String) throws {
        try db.transaction {
            try withPreparedStatement(deleteSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: sha1)
                try stepStatement(statement)
            }
        }
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

    private func normalizedFileName(from originalFileName: String?) -> String {
        let trimmedName = originalFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.flatMap { $0.isEmpty ? nil : $0 } ?? "skin.png"
    }

    private func decodeItem(from statement: OpaquePointer) -> SkinLibraryItem? {
        guard let originalFileName = SQLiteDatabase.stringColumn(statement, index: 0),
              let sha1 = SQLiteDatabase.stringColumn(statement, index: 1),
              let modelRawValue = SQLiteDatabase.stringColumn(statement, index: 2),
              let model = PlayerSkinService.PublicSkinInfo.SkinModel(rawValue: modelRawValue) else {
            return nil
        }

        return SkinLibraryItem(
            originalFileName: originalFileName,
            sha1: sha1,
            model: model,
            lastUsedAt: SQLiteDatabase.dateColumn(statement, index: 3),
        )
    }
}
