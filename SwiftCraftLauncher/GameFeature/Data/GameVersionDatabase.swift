//
//  GameVersionDatabase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SQLite3

/// Provides SQLite storage for game version information.
///
/// Uses WAL mode and mmap optimization for concurrent access and crash recovery.
/// Game data is stored as JSON blobs, indexed by working path and game name.
class GameVersionDatabase {

    private let db: SQLiteDatabase
    private let tableName = AppConstants.DatabaseTables.gameVersions
    private var isInitialized = false

    /// Creates a game version database.
    ///
    /// - Parameter dbPath: The file path for the SQLite database.
    init(dbPath: String) {
        self.db = SQLiteDatabase(path: dbPath)
    }

    /// Opens the database and creates the table schema if needed.
    func initialize() throws {
        if isInitialized {
            return
        }
        try db.open()
        try createTable()
        isInitialized = true
    }

    private func createTable() throws {
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

        let indexes = [
            ("idx_working_path", "working_path"),
            ("idx_last_played", "last_played"),
            ("idx_game_name", "game_name"),
        ]

        for (indexName, column) in indexes {
            let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS \(indexName) ON \(tableName)(\(column));
            """
            try? db.execute(createIndexSQL)
        }

        Logger.shared.debug("游戏版本表已创建或已存在")
    }

    /// Saves a game version to the database.
    ///
    /// - Parameters:
    ///   - game: The game version to save.
    ///   - workingPath: The working path associated with the game.
    func saveGame(_ game: GameVersionInfo, workingPath: String) throws {
        try db.transaction {
            let encoder = JSONEncoder()
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

    /// Saves multiple game versions to the database within a single transaction.
    ///
    /// - Parameters:
    ///   - games: The game versions to save.
    ///   - workingPath: The working path associated with the games.
    func saveGames(_ games: [GameVersionInfo], workingPath: String) throws {
        try db.transaction {
            let encoder = JSONEncoder()
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

    /// Loads all games for the specified working path.
    ///
    /// - Parameter workingPath: The working path to load games for.
    /// - Returns: An array of game versions, ordered by last played date.
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

    /// Loads all games grouped by working path.
    ///
    /// - Returns: A dictionary of working paths to their associated game arrays.
    func loadAllGames() throws -> [String: [GameVersionInfo]] {
        let sql = """
        SELECT working_path, data_json FROM \(tableName)
        ORDER BY working_path, last_played DESC
        """

        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var gamesByPath: [String: [GameVersionInfo]] = [:]
        let decoder = JSONDecoder()
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

    /// Returns all working paths with their game counts.
    ///
    /// Uses a SQL `GROUP BY` query without loading JSON payloads.
    func loadWorkingPathsWithCounts() throws -> [(path: String, count: Int)] {
        let sql = """
        SELECT working_path, COUNT(*) FROM \(tableName)
        GROUP BY working_path
        ORDER BY working_path
        """
        let statement = try db.prepare(sql)
        defer { sqlite3_finalize(statement) }
        var result: [(String, Int)] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let path = SQLiteDatabase.stringColumn(statement, index: 0) else { continue }
            let count = Int(SQLiteDatabase.intColumn(statement, index: 1))
            result.append((path, count))
        }
        return result
    }

    /// Retrieves a game by its identifier.
    ///
    /// - Parameter id: The unique identifier of the game.
    /// - Returns: The game version, or `nil` if no matching record exists.
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
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(GameVersionInfo.self, from: jsonData)
    }

    /// Deletes a game by its identifier.
    ///
    /// - Parameter id: The unique identifier of the game to delete.
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

    /// Deletes all games for the specified working path.
    ///
    /// - Parameter workingPath: The working path whose games should be deleted.
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

    /// Deletes games matching the specified working path and game name.
    ///
    /// Multiple records with the same name may exist for a single working path.
    ///
    /// - Parameters:
    ///   - workingPath: The working path to match.
    ///   - gameName: The game name to match.
    func deleteGames(workingPath: String, gameName: String) throws {
        try db.transaction {
            let sql = "DELETE FROM \(tableName) WHERE working_path = ? AND game_name = ?"
            let statement = try db.prepare(sql)
            defer { sqlite3_finalize(statement) }

            SQLiteDatabase.bind(statement, index: 1, value: workingPath)
            SQLiteDatabase.bind(statement, index: 2, value: gameName)

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

    /// Updates the last played date for a game.
    ///
    /// - Parameters:
    ///   - id: The unique identifier of the game.
    ///   - lastPlayed: The new last played date.
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

    func close() {
        db.close()
    }
}
