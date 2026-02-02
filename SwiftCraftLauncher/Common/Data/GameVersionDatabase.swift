import Foundation
import SQLite3

/// 游戏版本数据库存储层
/// 使用 SQLite (WAL + mmap + JSON1) 存储游戏版本信息
class GameVersionDatabase {
    // MARK: - Properties

    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.gameVersions

    // MARK: - Initialization

    /// 初始化游戏版本数据库
    /// - Parameter dbPath: 数据库文件路径
    init(dbPath: String) {
        self.db = SQLiteDatabase(path: dbPath)
    }

    // MARK: - Database Setup

    /// 打开数据库并初始化表结构
    /// - Throws: GlobalError 当操作失败时
    func initialize() throws {
        try db.open()
        try createTable()
    }

    /// 创建游戏版本表
    /// 使用 JSON1 扩展存储完整的游戏版本信息
    private func createTable() throws {
        // 创建表
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS \(tableName) (
            id TEXT PRIMARY KEY,
            working_path TEXT NOT NULL,
            game_name TEXT NOT NULL,
            data_json TEXT NOT NULL,
            last_played REAL NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """

        try db.execute(createTableSQL)

        // 创建索引（如果不存在）
        let indexes = [
            ("idx_working_path", "working_path"),
            ("idx_last_played", "last_played"),
            ("idx_game_name", "game_name"),
        ]

        for (indexName, column) in indexes {
            let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS \(indexName) ON \(tableName)(\(column));
            """
            try? db.execute(createIndexSQL) // 使用 try? 因为索引可能已存在
        }

        Logger.shared.debug("游戏版本表已创建或已存在")
    }

    // MARK: - CRUD Operations

    /// 保存游戏版本信息
    /// - Parameters:
    ///   - game: 游戏版本信息
    ///   - workingPath: 工作路径
    /// - Throws: GlobalError 当操作失败时
    func saveGame(_ game: GameVersionInfo, workingPath: String) throws {
        try db.transaction {
            let encoder = JSONEncoder()
            // 使用秒级时间戳编码日期（与 UserDefaults 存储兼容）
            encoder.dateEncodingStrategy = .secondsSince1970
            let jsonData = try encoder.encode(game)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw GlobalError.validation(
                    chineseMessage: "无法编码游戏数据为 JSON",
                    i18nKey: "error.validation.json_encode_failed",
                    level: .notification
                )
            }

            let now = Date()
            let sql = """
            INSERT OR REPLACE INTO \(tableName)
            (id, working_path, game_name, data_json, last_played, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?,
                COALESCE((SELECT created_at FROM \(tableName) WHERE id = ?), ?),
                ?)
            """

            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: game.id)
            SQLiteDatabase.bind(statement, index: 2, value: workingPath)
            SQLiteDatabase.bind(statement, index: 3, value: game.gameName)
            SQLiteDatabase.bind(statement, index: 4, value: jsonString)
            SQLiteDatabase.bind(statement, index: 5, value: game.lastPlayed)
            SQLiteDatabase.bind(statement, index: 6, value: game.id)
            SQLiteDatabase.bind(statement, index: 7, value: now)
            SQLiteDatabase.bind(statement, index: 8, value: now)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    chineseMessage: "保存游戏失败: \(errorMessage)",
                    i18nKey: "error.validation.game_save_failed",
                    level: .notification
                )
            }
        }
    }

    /// 批量保存游戏版本信息
    /// - Parameters:
    ///   - games: 游戏版本信息数组
    ///   - workingPath: 工作路径
    /// - Throws: GlobalError 当操作失败时
    func saveGames(_ games: [GameVersionInfo], workingPath: String) throws {
        try db.transaction {
            let encoder = JSONEncoder()
            // 使用秒级时间戳编码日期（与 UserDefaults 存储兼容）
            encoder.dateEncodingStrategy = .secondsSince1970
            let now = Date()

            let sql = """
            INSERT OR REPLACE INTO \(tableName)
            (id, working_path, game_name, data_json, last_played, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?,
                COALESCE((SELECT created_at FROM \(tableName) WHERE id = ?), ?),
                ?)
            """

            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            for game in games {
                let jsonData = try encoder.encode(game)
                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    continue
                }

                sqlite3_reset(statement)
                SQLiteDatabase.bind(statement, index: 1, value: game.id)
                SQLiteDatabase.bind(statement, index: 2, value: workingPath)
                SQLiteDatabase.bind(statement, index: 3, value: game.gameName)
                SQLiteDatabase.bind(statement, index: 4, value: jsonString)
                SQLiteDatabase.bind(statement, index: 5, value: game.lastPlayed)
                SQLiteDatabase.bind(statement, index: 6, value: game.id)
                SQLiteDatabase.bind(statement, index: 7, value: now)
                SQLiteDatabase.bind(statement, index: 8, value: now)

                let result = sqlite3_step(statement)
                guard result == SQLITE_DONE else {
                    let errorMessage = String(cString: sqlite3_errmsg(db.database))
                    throw GlobalError.validation(
                        chineseMessage: "批量保存游戏失败: \(errorMessage)",
                        i18nKey: "error.validation.games_batch_save_failed",
                        level: .notification
                    )
                }
            }
        }
    }

    /// 加载指定工作路径的所有游戏
    /// - Parameter workingPath: 工作路径
    /// - Returns: 游戏版本信息数组
    /// - Throws: GlobalError 当操作失败时
    func loadGames(workingPath: String) throws -> [GameVersionInfo] {
        let sql = """
        SELECT data_json FROM \(tableName)
        WHERE working_path = ?
        ORDER BY last_played DESC
        """

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        SQLiteDatabase.bind(statement, index: 1, value: workingPath)

        var games: [GameVersionInfo] = []
        let decoder = JSONDecoder()
        // 使用秒级时间戳解码日期（与 UserDefaults 存储兼容）
        decoder.dateDecodingStrategy = .secondsSince1970

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let jsonString = SQLiteDatabase.stringColumn(statement, index: 0),
                  let jsonData = jsonString.data(using: .utf8) else {
                continue
            }

            do {
                let game = try decoder.decode(GameVersionInfo.self, from: jsonData)
                games.append(game)
            } catch {
                Logger.shared.warning("解码游戏数据失败: \(error.localizedDescription)")
                continue
            }
        }

        return games
    }

    /// 加载所有工作路径的游戏（按工作路径分组）
    /// - Returns: 按工作路径分组的游戏字典
    /// - Throws: GlobalError 当操作失败时
    func loadAllGames() throws -> [String: [GameVersionInfo]] {
        let sql = """
        SELECT working_path, data_json FROM \(tableName)
        ORDER BY working_path, last_played DESC
        """

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var gamesByPath: [String: [GameVersionInfo]] = [:]
        let decoder = JSONDecoder()
        // 使用秒级时间戳解码日期（与 UserDefaults 存储兼容）
        decoder.dateDecodingStrategy = .secondsSince1970

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let workingPath = SQLiteDatabase.stringColumn(statement, index: 0),
                  let jsonString = SQLiteDatabase.stringColumn(statement, index: 1),
                  let jsonData = jsonString.data(using: .utf8) else {
                continue
            }

            do {
                let game = try decoder.decode(GameVersionInfo.self, from: jsonData)
                if gamesByPath[workingPath] == nil {
                    gamesByPath[workingPath] = []
                }
                gamesByPath[workingPath]?.append(game)
            } catch {
                Logger.shared.warning("解码游戏数据失败: \(error.localizedDescription)")
                continue
            }
        }

        return gamesByPath
    }

    /// 根据 ID 获取游戏
    /// - Parameter id: 游戏 ID
    /// - Returns: 游戏版本信息，如果不存在则返回 nil
    /// - Throws: GlobalError 当操作失败时
    func getGame(by id: String) throws -> GameVersionInfo? {
        let sql = "SELECT data_json FROM \(tableName) WHERE id = ? LIMIT 1"

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        SQLiteDatabase.bind(statement, index: 1, value: id)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let jsonString = SQLiteDatabase.stringColumn(statement, index: 0),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        let decoder = JSONDecoder()
        // 使用秒级时间戳解码日期（与 UserDefaults 存储兼容）
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(GameVersionInfo.self, from: jsonData)
    }

    /// 删除游戏
    /// - Parameter id: 游戏 ID
    /// - Throws: GlobalError 当操作失败时
    func deleteGame(id: String) throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName) WHERE id = ?"
            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: id)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    chineseMessage: "删除游戏失败: \(errorMessage)",
                    i18nKey: "error.validation.game_delete_failed",
                    level: .notification
                )
            }
        }
    }

    /// 删除指定工作路径的所有游戏
    /// - Parameter workingPath: 工作路径
    /// - Throws: GlobalError 当操作失败时
    func deleteGames(workingPath: String) throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName) WHERE working_path = ?"
            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: workingPath)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    chineseMessage: "删除工作路径游戏失败: \(errorMessage)",
                    i18nKey: "error.validation.games_delete_failed",
                    level: .notification
                )
            }
        }
    }

    /// 更新游戏最后游玩时间
    /// - Parameters:
    ///   - id: 游戏 ID
    ///   - lastPlayed: 最后游玩时间
    /// - Throws: GlobalError 当操作失败时
    func updateLastPlayed(id: String, lastPlayed: Date) throws {
        try db.transaction {
            let timestamp = lastPlayed.timeIntervalSince1970
            let sql = """
            UPDATE \(tableName)
            SET data_json = json_set(data_json, '$.lastPlayed', ?),
                last_played = ?,
                updated_at = ?
            WHERE id = ?
            """

            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: String(timestamp))
            SQLiteDatabase.bind(statement, index: 2, value: lastPlayed)
            SQLiteDatabase.bind(statement, index: 3, value: Date())
            SQLiteDatabase.bind(statement, index: 4, value: id)

            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE else {
                let errorMessage = String(cString: sqlite3_errmsg(db.database))
                throw GlobalError.validation(
                    chineseMessage: "更新最后游玩时间失败: \(errorMessage)",
                    i18nKey: "error.validation.last_played_update_failed",
                    level: .notification
                )
            }
        }
    }

    /// 关闭数据库连接
    func close() {
        db.close()
    }
}
