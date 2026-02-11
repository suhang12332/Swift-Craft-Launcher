import Foundation

/// Mod 缓存管理器
/// 使用 SQLite 数据库存储 mod.json 数据（hash -> JSON BLOB）
class ModCacheManager {
    static let shared = ModCacheManager()

    private let modCacheDB: ModCacheDatabase
    private let queue = DispatchQueue(label: "ModCacheManager.queue")
    private var isInitialized = false

    private init() {
        let dbPath = AppPaths.gameVersionDatabase.path
        self.modCacheDB = ModCacheDatabase(dbPath: dbPath)
    }

    // MARK: - Initialization

    /// 初始化数据库连接
    /// - Throws: GlobalError 当操作失败时
    private func ensureInitialized() throws {
        if !isInitialized {
            // 确保数据库目录存在
            let dataDir = AppPaths.dataDirectory
            try? FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)

            try modCacheDB.open()
            isInitialized = true
        }
    }

    // MARK: - Public API

    /// - Parameters:
    ///   - hash: mod 文件的 hash 值
    ///   - jsonData: JSON 数据的 Data（原始 JSON bytes）
    /// - Throws: GlobalError 当操作失败时
    func set(hash: String, jsonData: Data) throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.saveModCache(hash: hash, jsonData: jsonData)
        }
    }

    /// - Parameters:
    ///   - hash: mod 文件的 hash 值
    ///   - jsonData: JSON 数据的 Data（原始 JSON bytes）
    func setSilently(hash: String, jsonData: Data) {
        do {
            try set(hash: hash, jsonData: jsonData)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 获取 mod 缓存值
    /// - Parameter hash: mod 文件的 hash 值
    /// - Returns: JSON 数据的 Data（原始 JSON bytes），如果不存在则返回 nil
    func get(hash: String) -> Data? {
        return queue.sync {
            do {
                try ensureInitialized()
                return try modCacheDB.getModCache(hash: hash)
            } catch {
                GlobalErrorHandler.shared.handle(error)
                return nil
            }
        }
    }

    /// 获取所有 mod 缓存数据
    /// - Returns: hash -> JSON Data 的字典
    func getAll() -> [String: Data] {
        return queue.sync {
            do {
                try ensureInitialized()
                return try modCacheDB.getAllModCaches()
            } catch {
                GlobalErrorHandler.shared.handle(error)
                return [:]
            }
        }
    }

    /// 移除 mod 缓存项
    /// - Parameter hash: mod 文件的 hash 值
    /// - Throws: GlobalError 当操作失败时
    func remove(hash: String) throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.deleteModCache(hash: hash)
        }
    }

    /// 移除 mod 缓存项（静默版本）
    /// - Parameter hash: mod 文件的 hash 值
    func removeSilently(hash: String) {
        do {
            try remove(hash: hash)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 批量移除 mod 缓存项
    /// - Parameter hashes: 要删除的 hash 数组
    /// - Throws: GlobalError 当操作失败时
    func remove(hashes: [String]) throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.deleteModCaches(hashes: hashes)
        }
    }

    /// 批量移除 mod 缓存项（静默版本）
    /// - Parameter hashes: 要删除的 hash 数组
    func removeSilently(hashes: [String]) {
        do {
            try remove(hashes: hashes)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 清空所有 mod 缓存
    /// - Throws: GlobalError 当操作失败时
    func clear() throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.clearAllModCaches()
        }
    }

    /// 清空所有 mod 缓存（静默版本）
    func clearSilently() {
        do {
            try clear()
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// - Parameter hash: mod 文件的 hash 值
    /// - Returns: 是否存在
    func has(hash: String) -> Bool {
        return queue.sync {
            do {
                try ensureInitialized()
                return try modCacheDB.hasModCache(hash: hash)
            } catch {
                GlobalErrorHandler.shared.handle(error)
                return false
            }
        }
    }

    /// - Parameter data: hash -> JSON Data 的字典
    /// - Throws: GlobalError 当操作失败时
    func setAll(_ data: [String: Data]) throws {
        try queue.sync {
            try ensureInitialized()
            try modCacheDB.saveModCaches(data)
        }
    }

    /// - Parameter data: hash -> JSON Data 的字典
    func setAllSilently(_ data: [String: Data]) {
        do {
            try setAll(data)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }
}
