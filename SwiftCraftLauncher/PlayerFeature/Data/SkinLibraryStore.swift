import Foundation
import SQLite3

final class SkinLibraryStore {
    private let fileManager: FileManager
    private let database: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.skinLibrary
    private var isInitialized = false

    private let selectColumns = "original_file_name, sha1, model, last_used_at"
    private let createTableSQL: String
    private let upsertSQL: String
    private let deleteSQL: String
    private let selectAllSQL: String
    private let findBySHA1SQL: String

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.database = SQLiteDatabase(path: AppPaths.gameVersionDatabase.path)
        self.createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(AppConstants.DatabaseTables.skinLibrary) (
            original_file_name TEXT NOT NULL,
            sha1 TEXT NOT NULL PRIMARY KEY,
            model TEXT NOT NULL,
            last_used_at REAL NOT NULL
        );
        """
        self.upsertSQL = """
        INSERT OR REPLACE INTO \(AppConstants.DatabaseTables.skinLibrary)
        (original_file_name, sha1, model, last_used_at)
        VALUES (?, ?, ?, ?)
        """
        self.deleteSQL = "DELETE FROM \(AppConstants.DatabaseTables.skinLibrary) WHERE sha1 = ?"
        self.selectAllSQL = """
        SELECT \(selectColumns)
        FROM \(tableName)
        ORDER BY last_used_at DESC
        """
        self.findBySHA1SQL = """
        SELECT \(selectColumns)
        FROM \(tableName)
        WHERE sha1 = ?
        LIMIT 1
        """
    }

    func loadItems() -> [SkinLibraryItem] {
        do {
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
        } catch {
            Logger.shared.error("Failed to load skin library: \(error.localizedDescription)")
            return []
        }
    }

    @discardableResult
    func saveSkin(
        data: Data,
        model: PlayerSkinService.PublicSkinInfo.SkinModel,
        originalFileName: String?
    ) -> SkinLibraryItem? {
        do {
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
                lastUsedAt: now
            )

            try upsert(item)
            return item
        } catch {
            Logger.shared.error("Failed to save skin into library: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteItem(_ item: SkinLibraryItem) -> Bool {
        do {
            try initializeIfNeeded()

            if fileManager.fileExists(atPath: item.fileURL.path) {
                try fileManager.removeItem(at: item.fileURL)
            }

            try deleteItemRecord(sha1: item.sha1)
            return true
        } catch {
            Logger.shared.error("Failed to delete skin library item: \(error.localizedDescription)")
            return false
        }
    }

    private func initializeIfNeeded() throws {
        if isInitialized {
            return
        }

        try ensureDirectoriesIfNeeded()
        try database.open()
        try migrateTableIfNeeded()
        try createTableIfNeeded()
        try createIndexesIfNeeded()
        isInitialized = true
    }

    private func ensureDirectoriesIfNeeded() throws {
        try fileManager.createDirectory(
            at: AppPaths.skinsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func createTableIfNeeded() throws {
        try database.execute(createTableSQL)
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

        try database.transaction {
            let tempTable = "\(tableName)_new"
            try database.execute("""
            CREATE TABLE IF NOT EXISTS \(tempTable) (
                original_file_name TEXT NOT NULL,
                sha1 TEXT NOT NULL PRIMARY KEY,
                model TEXT NOT NULL,
                last_used_at REAL NOT NULL
            );
            """)
            try database.execute("""
            INSERT OR REPLACE INTO \(tempTable) (original_file_name, sha1, model, last_used_at)
            SELECT original_file_name, sha1, model, last_used_at
            FROM \(tableName);
            """)
            try database.execute("DROP TABLE \(tableName);")
            try database.execute("ALTER TABLE \(tempTable) RENAME TO \(tableName);")
        }
    }

    private func createIndexesIfNeeded() throws {
        try? database.execute(
            "CREATE INDEX IF NOT EXISTS idx_skin_library_last_used_at ON \(tableName)(last_used_at DESC);"
        )
        try? database.execute(
            "CREATE INDEX IF NOT EXISTS idx_skin_library_sha1 ON \(tableName)(sha1);"
        )
    }

    private func findItem(sha1: String) throws -> SkinLibraryItem? {
        try withPreparedStatement(findBySHA1SQL) { statement in
            SQLiteDatabase.bind(statement, index: 1, value: sha1)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return decodeItem(from: statement)
        }
    }

    private func upsert(_ item: SkinLibraryItem) throws {
        try executeUpdate(upsertSQL, errorPrefix: "保存皮肤库失败") { statement in
            SQLiteDatabase.bind(statement, index: 1, value: item.originalFileName)
            SQLiteDatabase.bind(statement, index: 2, value: item.sha1)
            SQLiteDatabase.bind(statement, index: 3, value: item.model.rawValue)
            SQLiteDatabase.bind(statement, index: 4, value: item.lastUsedAt)
        }
    }

    private func deleteItemRecord(sha1: String) throws {
        try executeUpdate(deleteSQL, errorPrefix: "删除皮肤库记录失败") { statement in
            SQLiteDatabase.bind(statement, index: 1, value: sha1)
        }
    }

    private func withPreparedStatement<T>(
        _ sql: String,
        _ body: (OpaquePointer) throws -> T
    ) throws -> T {
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func executeUpdate(
        _ sql: String,
        errorPrefix: String = "SQL execution failed",
        bind: (OpaquePointer) throws -> Void
    ) throws {
        try database.transaction {
            try withPreparedStatement(sql) { statement in
                try bind(statement)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw GlobalError.validation(
                        chineseMessage: "\(errorPrefix): \(sqliteErrorMessage())",
                        i18nKey: "error.validation.sql_execution_failed",
                        level: .notification
                    )
                }
            }
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
            lastUsedAt: SQLiteDatabase.dateColumn(statement, index: 3)
        )
    }

    private func sqliteErrorMessage() -> String {
        guard let db = database.database else {
            return "Unknown SQLite error"
        }
        return String(cString: sqlite3_errmsg(db))
    }
}
