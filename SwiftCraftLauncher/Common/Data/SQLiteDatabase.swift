import Foundation
import SQLite3

/// SQLite 数据库管理器
/// 使用 WAL 模式和 mmap 优化性能
class SQLiteDatabase {
    // MARK: - Properties

    private var db: OpaquePointer?
    private let dbPath: String
    private let queue: DispatchQueue
    private static let queueKey = DispatchSpecificKey<Bool>()

    // MARK: - Initialization

    /// 初始化数据库连接
    /// - Parameters:
    ///   - path: 数据库文件路径
    ///   - queue: 数据库操作队列，默认为串行队列
    init(path: String, queue: DispatchQueue? = nil) {
        self.dbPath = path
        self.queue = queue ?? DispatchQueue(label: "com.swiftcraftlauncher.sqlite", qos: .utility)
        self.queue.setSpecific(key: Self.queueKey, value: true)
    }

    deinit {
        close()
    }

    // MARK: - Connection Management

    private var isOnQueue: Bool {
        return DispatchQueue.getSpecific(key: Self.queueKey) != nil
    }

    /// 在队列中执行操作（如果已在队列内则直接执行）
    private func sync<T>(_ block: () throws -> T) rethrows -> T {
        if isOnQueue {
            return try block()
        } else {
            return try queue.sync(execute: block)
        }
    }

    /// 打开数据库连接
    /// - Throws: GlobalError 当连接失败时
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
                    level: .notification
                )
            }

            self.db = openedDb

            // 启用 WAL 模式
            try enableWALMode()

            // 启用 mmap
            try enableMmap()

            // 启用 JSON1 扩展（SQLite 3.9.0+ 内置）
            // JSON1 扩展默认已启用，无需额外操作

            Logger.shared.debug("SQLite 数据库已打开: \(dbPath)")
        }
    }

    /// 关闭数据库连接
    func close() {
        sync {
            guard let db = db else { return }
            sqlite3_close(db)
            self.db = nil
            Logger.shared.debug("SQLite 数据库已关闭")
        }
    }

    /// 启用 WAL 模式（Write-Ahead Logging）
    /// 提供更好的并发性能和崩溃恢复能力
    private func enableWALMode() throws {
        guard let db = db else { return }

        let result = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw GlobalError.validation(
                chineseMessage: "无法启用 WAL 模式: \(errorMessage)",
                i18nKey: "error.validation.wal_mode_failed",
                level: .notification
            )
        }

        sqlite3_exec(db, "PRAGMA wal_autocheckpoint=1000;", nil, nil, nil)

        Logger.shared.debug("WAL 模式已启用")
    }

    /// 启用 mmap（内存映射）
    /// 允许 SQLite 使用操作系统虚拟内存系统来访问数据库文件
    private func enableMmap() throws {
        guard let db = db else { return }

        // 设置 mmap 大小为 64MB（可根据需要调整）
        let mmapSize = 64 * 1024 * 1024
        let sql = "PRAGMA mmap_size=\(mmapSize);"

        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw GlobalError.validation(
                chineseMessage: "无法启用 mmap: \(errorMessage)",
                i18nKey: "error.validation.mmap_failed",
                level: .notification
            )
        }

        Logger.shared.debug("mmap 已启用 (64MB)")
    }

    // MARK: - Transaction Management

    /// 执行事务操作
    /// - Parameter block: 事务块
    /// - Throws: GlobalError 当操作失败时
    func transaction<T>(_ block: () throws -> T) throws -> T {
        try sync {
            guard let db = db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification
                )
            }

            // 开始事务
            var result = sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
            guard result == SQLITE_OK else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw GlobalError.validation(
                    chineseMessage: "无法开始事务: \(errorMessage)",
                    i18nKey: "error.validation.transaction_begin_failed",
                    level: .notification
                )
            }

            do {
                let value = try block()

                // 提交事务
                result = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
                guard result == SQLITE_OK else {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    throw GlobalError.validation(
                        chineseMessage: "无法提交事务: \(errorMessage)",
                        i18nKey: "error.validation.transaction_commit_failed",
                        level: .notification
                    )
                }

                return value
            } catch {
                // 回滚事务
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                throw error
            }
        }
    }

    // MARK: - Query Execution

    /// 执行 SQL 语句（不返回结果）
    /// - Parameter sql: SQL 语句
    /// - Throws: GlobalError 当执行失败时
    func execute(_ sql: String) throws {
        try sync {
            guard let db = db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification
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
                    level: .notification
                )
            }
        }
    }

    /// 准备 SQL 语句
    /// - Parameter sql: SQL 语句
    /// - Returns: 准备好的语句指针
    /// - Throws: GlobalError 当准备失败时
    /// - Warning: 返回的 statement 必须在队列内使用，使用完毕后调用 sqlite3_finalize
    func prepare(_ sql: String) throws -> OpaquePointer {
        return try sync {
            guard let db = db else {
                throw GlobalError.validation(
                    chineseMessage: "数据库未打开",
                    i18nKey: "error.validation.database_not_open",
                    level: .notification
                )
            }

            var statement: OpaquePointer?
            let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)

            guard result == SQLITE_OK, let stmt = statement else {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw GlobalError.validation(
                    chineseMessage: "无法准备 SQL 语句: \(errorMessage)",
                    i18nKey: "error.validation.sql_prepare_failed",
                    level: .notification
                )
            }

            return stmt
        }
    }

    /// 获取数据库实例（用于直接操作）
    /// - Returns: SQLite 数据库指针
    /// - Warning: 仅在队列内使用
    var database: OpaquePointer? {
        return sync { db }
    }

    /// 在队列中执行操作
    /// - Parameter block: 操作块
    func perform<T>(_ block: @escaping (OpaquePointer?) throws -> T) throws -> T {
        return try sync {
            try block(db)
        }
    }
}

// MARK: - Statement Helpers

extension SQLiteDatabase {
    // SQLITE_TRANSIENT 的替代：使用 nil 让 SQLite 复制数据
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// 绑定字符串参数
    static func bind(_ statement: OpaquePointer, index: Int32, value: String?) {
        if let value = value {
            sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    /// 绑定整数参数
    static func bind(_ statement: OpaquePointer, index: Int32, value: Int) {
        sqlite3_bind_int64(statement, index, Int64(value))
    }

    /// 绑定日期参数（存储为时间戳）
    static func bind(_ statement: OpaquePointer, index: Int32, value: Date) {
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }

    /// 绑定 BLOB 参数
    static func bind(_ statement: OpaquePointer, index: Int32, data: Data) {
        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    /// 读取字符串列
    static func stringColumn(_ statement: OpaquePointer, index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }

    /// 读取整数列
    static func intColumn(_ statement: OpaquePointer, index: Int32) -> Int {
        return Int(sqlite3_column_int64(statement, index))
    }

    /// 读取日期列
    static func dateColumn(_ statement: OpaquePointer, index: Int32) -> Date {
        let timestamp = sqlite3_column_double(statement, index)
        return Date(timeIntervalSince1970: timestamp)
    }

    /// 读取 BLOB 列
    static func dataColumn(_ statement: OpaquePointer, index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(statement, index) else { return nil }
        let length = sqlite3_column_bytes(statement, index)
        return Data(bytes: blob, count: Int(length))
    }
}
