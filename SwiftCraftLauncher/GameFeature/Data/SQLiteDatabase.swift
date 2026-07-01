//
//  SQLiteDatabase.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SQLite3

/// A thread-safe wrapper around the SQLite C API.
///
/// Manages a single database connection with WAL journal mode and memory-mapped I/O.
/// All operations are serialized on a dedicated dispatch queue.
class SQLiteDatabase {
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue: DispatchQueue
    private static let queueKey = DispatchSpecificKey<Bool>()

    /// Creates a database connection.
    ///
    /// - Parameters:
    ///   - path: The file path of the SQLite database.
    ///   - queue: An optional dispatch queue for serializing operations.
    init(path: String, queue: DispatchQueue? = nil) {
        dbPath = path
        self.queue = queue ?? DispatchQueue(label: "com.swiftcraftlauncher.sqlite", qos: .utility)
        self.queue.setSpecific(key: Self.queueKey, value: true)
    }

    deinit {
        close()
    }

    private var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: Self.queueKey) != nil
    }

    private func sync<T>(_ block: () throws -> T) rethrows -> T {
        if isOnQueue {
            return try block()
        } else {
            return try queue.sync(execute: block)
        }
    }

    /// Opens the database connection.
    ///
    /// Enables WAL journal mode and memory-mapped I/O after opening.
    func open() throws {
        try sync {
            guard db == nil else { return }

            let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
            var tempDb: OpaquePointer?
            let result = sqlite3_open_v2(dbPath, &tempDb, flags, nil)

            guard result == SQLITE_OK, let openedDb = tempDb else {
                let errorMessage = tempDb.map { String(cString: sqlite3_errmsg($0)) } ?? "未知错误"
                if let dbToClose = tempDb {
                    sqlite3_close(dbToClose)
                }
                throw GlobalError.validation(
                    chineseMessage: "无法打开数据库: \(errorMessage)",
                    i18nKey: "error.validation.database_open_failed",
                    level: .notification,
                )
            }

            self.db = openedDb
            try enableWALMode()
            try enableMmap()
            AppLog.game.debug("SQLite 数据库已打开: \(self.dbPath)")
        }
    }

    /// Closes the database connection.
    func close() {
        sync {
            guard let db else { return }
            sqlite3_close(db)
            self.db = nil
            AppLog.game.debug("SQLite 数据库已关闭")
        }
    }

    private func enableWALMode() throws {
        guard let db else { return }

        let result = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw GlobalError.validation(
                chineseMessage: "无法启用 WAL 模式: \(errorMessage)",
                i18nKey: "error.validation.wal_mode_failed",
                level: .notification,
            )
        }

        sqlite3_exec(db, "PRAGMA wal_autocheckpoint=1000;", nil, nil, nil)

        AppLog.game.debug("WAL 模式已启用")
    }

    private func enableMmap() throws {
        guard let db else { return }

        let mmapSize = 64 * 1024 * 1024
        let sql = "PRAGMA mmap_size=\(mmapSize);"

        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw GlobalError.validation(
                chineseMessage: "无法启用 mmap: \(errorMessage)",
                i18nKey: "error.validation.mmap_failed",
                level: .notification,
            )
        }

        AppLog.game.debug("mmap 已启用 (64MB)")
    }

    /// Executes a block within a database transaction.
    ///
    /// The transaction is committed if the block succeeds, or rolled back if it throws.
    ///
    /// - Parameter block: The work to perform inside the transaction.
    /// - Returns: The value produced by the block.
    func transaction<T>(_ block: () throws -> T) throws -> T {
        try sync {
            guard let db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification,
                )
            }

            var result = sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
            guard result == SQLITE_OK else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw GlobalError.validation(
                    chineseMessage: "无法开始事务: \(errorMessage)",
                    i18nKey: "error.validation.transaction_begin_failed",
                    level: .notification,
                )
            }

            do {
                let value = try block()

                result = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
                guard result == SQLITE_OK else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    throw GlobalError.validation(
                        chineseMessage: "无法提交事务: \(errorMessage)",
                        i18nKey: "error.validation.transaction_commit_failed",
                        level: .notification,
                    )
                }

                return value
            } catch {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    /// Executes a SQL statement that does not return results.
    ///
    /// - Parameter sql: The SQL statement to execute.
    func execute(_ sql: String) throws {
        try sync {
            guard let db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification,
                )
            }

            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)

            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "未知错误"
                sqlite3_free(errorMessage)
                throw GlobalError.validation(
                    chineseMessage: "SQL 执行失败: \(message)",
                    i18nKey: "error.validation.sql_execution_failed",
                    level: .notification,
                )
            }
        }
    }

    /// Prepares a SQL statement for execution.
    ///
    /// The caller is responsible for calling `sqlite3_finalize` on the returned pointer.
    ///
    /// - Parameter sql: The SQL statement to prepare.
    /// - Returns: A pointer to the prepared statement.
    func prepare(_ sql: String) throws -> OpaquePointer {
        try sync {
            guard let db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification,
                )
            }

            var statement: OpaquePointer?
            let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)

            guard result == SQLITE_OK, let stmt = statement else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw GlobalError.validation(
                    chineseMessage: "无法准备 SQL 语句: \(errorMessage)",
                    i18nKey: "error.validation.sql_prepare_failed",
                    level: .notification,
                )
            }

            return stmt
        }
    }

    /// The underlying database pointer.
    var database: OpaquePointer? {
        sync { db }
    }

    /// Executes a block with direct access to the raw database pointer.
    ///
    /// - Parameter block: The work to perform with the database pointer.
    func perform<T>(_ block: @escaping (OpaquePointer?) throws -> T) throws -> T {
        try sync {
            try block(db)
        }
    }
}

extension SQLiteDatabase {
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Binds a string value to a statement parameter.
    static func bind(_ statement: OpaquePointer, index: Int32, value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    /// Binds an integer value to a statement parameter.
    static func bind(_ statement: OpaquePointer, index: Int32, value: Int) {
        sqlite3_bind_int64(statement, index, Int64(value))
    }

    /// Binds a date value to a statement parameter, stored as a Unix timestamp.
    static func bind(_ statement: OpaquePointer, index: Int32, value: Date) {
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }

    /// Binds binary data to a statement parameter.
    static func bind(_ statement: OpaquePointer, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    /// Reads a string value from a result column.
    static func stringColumn(_ statement: OpaquePointer, index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }

    /// Reads an integer value from a result column.
    static func intColumn(_ statement: OpaquePointer, index: Int32) -> Int {
        Int(sqlite3_column_int64(statement, index))
    }

    /// Reads a date value from a result column, interpreted as a Unix timestamp.
    static func dateColumn(_ statement: OpaquePointer, index: Int32) -> Date {
        let timestamp = sqlite3_column_double(statement, index)
        return Date(timeIntervalSince1970: timestamp)
    }

    /// Reads binary data from a result column.
    static func dataColumn(_ statement: OpaquePointer, index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(statement, index) else { return nil }
        let length = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(length))
    }
}
