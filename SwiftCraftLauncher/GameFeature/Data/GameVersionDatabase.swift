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

    private let upsertSQL: String
    private let selectByPathSQL: String
    private let selectAllSQL: String
    private let countByPathSQL: String
    private let selectByIdSQL: String
    private let deleteByIdSQL: String
    private let deleteByPathSQL: String
    private let deleteByPathAndNameSQL: String
    private let updateLastPlayedSQL: String

    init(dbPath: String) {
        db = SQLiteDatabase.database(at: dbPath)
        upsertSQL = """
        INSERT OR REPLACE INTO \(tableName)
        (id, working_path, game_name, data_json, last_played, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?,
            COALESCE((SELECT created_at FROM \(tableName) WHERE id = ?), ?),
            ?)
        """
        selectByPathSQL = """
        SELECT data_json FROM \(tableName)
        WHERE working_path = ?
        ORDER BY last_played DESC
        """
        selectAllSQL = """
        SELECT working_path, data_json FROM \(tableName)
        ORDER BY working_path, last_played DESC
        """
        countByPathSQL = """
        SELECT working_path, COUNT(*) FROM \(tableName)
        GROUP BY working_path
        ORDER BY working_path
        """
        selectByIdSQL = "SELECT data_json FROM \(tableName) WHERE id = ? LIMIT 1"
        deleteByIdSQL = "DELETE FROM \(tableName) WHERE id = ?"
        deleteByPathSQL = "DELETE FROM \(tableName) WHERE working_path = ?"
        deleteByPathAndNameSQL = "DELETE FROM \(tableName) WHERE working_path = ? AND game_name = ?"
        updateLastPlayedSQL = """
        UPDATE \(tableName)
        SET data_json = json_set(data_json, '$.lastPlayed', ?),
            last_played = ?,
            updated_at = ?
        WHERE id = ?
        """
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
            try? db.execute(
                "CREATE INDEX IF NOT EXISTS \(indexName) ON \(tableName)(\(column));",
            )
        }
        AppLog.game.debug("Game version table created or already exists")
    }

    /// Saves a game version to the database.
    ///
    /// - Parameters:
    ///   - game: The game version to save.
    ///   - workingPath: The working path associated with the game.
    func saveGame(_ game: GameVersionInfo, workingPath: String) throws {
        try db.transaction {
            let jsonString = try encodeGame(game)
            let now = Date()
            try withPreparedStatement(upsertSQL) { statement in
                bindGameStatement(statement, game: game, workingPath: workingPath, jsonString: jsonString, now: now)
                try stepStatement(statement)
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
            let now = Date()
            try withPreparedStatement(upsertSQL) { statement in
                for game in games {
                    guard let jsonString = try? encodeGame(game) else { continue }
                    sqlite3_reset(statement)
                    bindGameStatement(statement, game: game, workingPath: workingPath, jsonString: jsonString, now: now)
                    try stepStatement(statement)
                }
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
            try withPreparedStatement(updateLastPlayedSQL) { statement in
                let timestamp = lastPlayed.timeIntervalSince1970
                SQLiteDatabase.bind(statement, index: 1, value: String(timestamp))
                SQLiteDatabase.bind(statement, index: 2, value: lastPlayed)
                SQLiteDatabase.bind(statement, index: 3, value: Date())
                SQLiteDatabase.bind(statement, index: 4, value: id)
                try stepStatement(statement)
            }
        }
    }

    /// Loads all games for the specified working path.
    ///
    /// - Parameter workingPath: The working path to load games for.
    /// - Returns: An array of game versions, ordered by last played date.
    func loadGames(workingPath: String) throws -> [GameVersionInfo] {
        var games: [GameVersionInfo] = []
        try withPreparedStatement(selectByPathSQL) { statement in
            SQLiteDatabase.bind(statement, index: 1, value: workingPath)
            while sqlite3_step(statement) == SQLITE_ROW {
                if let game = decodeGameFromStatement(statement, columnIndex: 0) {
                    games.append(game)
                }
            }
        }
        return games
    }

    /// Loads all games grouped by working path.
    ///
    /// - Returns: A dictionary of working paths to their associated game arrays.
    func loadAllGames() throws -> [String: [GameVersionInfo]] {
        var gamesByPath: [String: [GameVersionInfo]] = [:]
        try withPreparedStatement(selectAllSQL) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let workingPath = SQLiteDatabase.stringColumn(statement, index: 0),
                      let game = decodeGameFromStatement(statement, columnIndex: 1) else {
                    continue
                }
                gamesByPath[workingPath, default: []].append(game)
            }
        }
        return gamesByPath
    }

    /// Returns all working paths with their game counts.
    ///
    /// Uses a SQL `GROUP BY` query without loading JSON payloads.
    func loadWorkingPathsWithCounts() throws -> [(path: String, count: Int)] {
        var result: [(String, Int)] = []
        try withPreparedStatement(countByPathSQL) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let path = SQLiteDatabase.stringColumn(statement, index: 0) else { continue }
                let count = Int(SQLiteDatabase.intColumn(statement, index: 1))
                result.append((path, count))
            }
        }
        return result
    }

    /// Retrieves a game by its identifier.
    ///
    /// - Parameter id: The unique identifier of the game.
    /// - Returns: The game version, or `nil` if no matching record exists.
    func getGame(by id: String) throws -> GameVersionInfo? {
        var result: GameVersionInfo?
        try withPreparedStatement(selectByIdSQL) { statement in
            SQLiteDatabase.bind(statement, index: 1, value: id)
            if sqlite3_step(statement) == SQLITE_ROW {
                result = decodeGameFromStatement(statement, columnIndex: 0)
            }
        }
        return result
    }

    /// Deletes a game by its identifier.
    ///
    /// - Parameter id: The unique identifier of the game to delete.
    func deleteGame(id: String) throws {
        try db.transaction {
            try withPreparedStatement(deleteByIdSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: id)
                try stepStatement(statement)
            }
        }
    }

    /// Deletes all games for the specified working path.
    ///
    /// - Parameter workingPath: The working path whose games should be deleted.
    func deleteGames(workingPath: String) throws {
        try db.transaction {
            try withPreparedStatement(deleteByPathSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: workingPath)
                try stepStatement(statement)
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
            try withPreparedStatement(deleteByPathAndNameSQL) { statement in
                SQLiteDatabase.bind(statement, index: 1, value: workingPath)
                SQLiteDatabase.bind(statement, index: 2, value: gameName)
                try stepStatement(statement)
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

    private func encodeGame(_ game: GameVersionInfo) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let jsonData = try encoder.encode(game)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw GlobalError.validation(
                i18nKey: "error.validation.json_encode_failed",
                level: .notification,
                message: "Failed to encode game=\(game.gameName) id=\(game.id) to UTF-8 JSON string",
            )
        }
        return jsonString
    }

    private func decodeGameFromStatement(_ statement: OpaquePointer, columnIndex: Int32) -> GameVersionInfo? {
        guard let jsonString = SQLiteDatabase.stringColumn(statement, index: columnIndex),
              let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(GameVersionInfo.self, from: jsonData)
    }

    private func bindGameStatement(
        _ statement: OpaquePointer,
        game: GameVersionInfo,
        workingPath: String,
        jsonString: String,
        now: Date,
    ) {
        SQLiteDatabase.bind(statement, index: 1, value: game.id)
        SQLiteDatabase.bind(statement, index: 2, value: workingPath)
        SQLiteDatabase.bind(statement, index: 3, value: game.gameName)
        SQLiteDatabase.bind(statement, index: 4, value: jsonString)
        SQLiteDatabase.bind(statement, index: 5, value: game.lastPlayed)
        SQLiteDatabase.bind(statement, index: 6, value: game.id)
        SQLiteDatabase.bind(statement, index: 7, value: now)
        SQLiteDatabase.bind(statement, index: 8, value: now)
    }
}
