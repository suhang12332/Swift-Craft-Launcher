import Foundation
import SQLite3

/// Mod 缓存数据库存储层
/// 使用 SQLite 存储 mod.json 数据（hash -> JSON BLOB）
class ModCacheDatabase {
    // MARK: - Properties

    private let db: SQLiteDatabase
    private let tableName = "mod_cache"

    // MARK: - Initialization

    /// 初始化 Mod 缓存数据库
    /// - Parameter dbPath: 数据库文件路径
    init(dbPath: String) {
        self.db = SQLiteDatabase(path: dbPath)
    }

    // MARK: - Database Setup

    /// 打开数据库连接并创建表（如果不存在）
    /// - Throws: GlobalError 当操作失败时
    func open() throws {
        try db.open()
        try createTable()
    }

    /// 创建 mod 缓存表
    /// 用于存储 mod.json 数据（hash -> JSON BLOB）
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

        // 创建索引（如果不存在）
        let createIndexSQL = """
        CREATE INDEX IF NOT EXISTS idx_mod_cache_updated_at ON \(tableName)(updated_at);
        """
        try? db.execute(createIndexSQL)

        Logger.shared.debug("mod 缓存表已创建或已存在")
    }

    /// 关闭数据库连接
    func close() {
        db.close()
    }

    // MARK: - CRUD Operations

    /// 保存 mod 缓存数据
    /// - Parameters:
    ///   - hash: mod 文件的 hash 值
    ///   - jsonData: JSON 数据的 Data（原始 JSON bytes）
    /// - Throws: GlobalError 当操作失败时
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
                    chineseMessage: "保存 mod 缓存失败: \(errorMessage)",
                    i18nKey: "error.validation.mod_cache_save_failed",
                    level: .notification
                )
            }
        }
    }

    /// 批量保存 mod 缓存数据
    /// - Parameter data: hash -> JSON Data 的字典
    /// - Throws: GlobalError 当操作失败时
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
                        chineseMessage: "批量保存 mod 缓存失败: \(errorMessage)",
                        i18nKey: "error.validation.mod_cache_batch_save_failed",
                        level: .notification
                    )
                }
            }
        }
    }

    /// 获取 mod 缓存数据
    /// - Parameter hash: mod 文件的 hash 值
    /// - Returns: JSON 数据的 Data（原始 JSON bytes），如果不存在则返回 nil
    /// - Throws: GlobalError 当操作失败时
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

    /// 获取所有 mod 缓存数据
    /// - Returns: hash -> JSON Data 的字典
    /// - Throws: GlobalError 当操作失败时
    func getAllModCaches() throws -> [String: Data] {
        let sql = "SELECT hash, json_data FROM \(tableName)"

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var result: [String: Data] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let hash = SQLiteDatabase.stringColumn(statement, index: 0),
                  let jsonData = SQLiteDatabase.dataColumn(statement, index: 1) else {
                continue
            }
            result[hash] = jsonData
        }

        return result
    }

    /// 删除 mod 缓存数据
    /// - Parameter hash: mod 文件的 hash 值
    /// - Throws: GlobalError 当操作失败时
    func deleteModCache(hash: String) throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName) WHERE hash = ?"
            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: hash)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    chineseMessage: "删除 mod 缓存失败: \(errorMessage)",
                    i18nKey: "error.validation.mod_cache_delete_failed",
                    level: .notification
                )
            }
        }
    }

    /// 批量删除 mod 缓存数据
    /// - Parameter hashes: 要删除的 hash 数组
    /// - Throws: GlobalError 当操作失败时
    func deleteModCaches(hashes: [String]) throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName) WHERE hash = ?"
            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            for hash in hashes {
                sqlite3_reset(statement)
                SQLiteDatabase.bind(statement, index: 1, value: hash)

                let result = sqlite3_step(statement)
                guard result == SQLITE_DONE else {
                    let errorMessage = String(cString: sqlite3_errmsg(db.database))
                    throw GlobalError.validation(
                        chineseMessage: "批量删除 mod 缓存失败: \(errorMessage)",
                        i18nKey: "error.validation.mod_cache_batch_delete_failed",
                        level: .notification
                    )
                }
            }
        }
    }

    /// 清空所有 mod 缓存数据
    /// - Throws: GlobalError 当操作失败时
    func clearAllModCaches() throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName)"
            try db.execute(sql)
        }
    }

    /// 检查是否存在指定的 mod 缓存
    /// - Parameter hash: mod 文件的 hash 值
    /// - Returns: 是否存在
    /// - Throws: GlobalError 当操作失败时
    func hasModCache(hash: String) throws -> Bool {
        let sql = "SELECT 1 FROM \(tableName) WHERE hash = ? LIMIT 1"

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        SQLiteDatabase.bind(statement, index: 1, value: hash)

        return sqlite3_step(statement) == SQLITE_ROW
    }
}
