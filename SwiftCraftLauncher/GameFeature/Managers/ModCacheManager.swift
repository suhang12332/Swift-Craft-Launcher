import Foundation

/// Mod 缓存管理器
/// 使用 SQLite 数据库存储 mod.json 数据（hash -> JSON BLOB）
class ModCacheManager {
    static let shared = ModCacheManager()

    private let modCacheDB: ModCacheDatabase
    private let errorHandler: GlobalErrorHandler
    private let queue = DispatchQueue(label: "ModCacheManager.queue")
    private var isInitialized = false

    private init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
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
            errorHandler.handle(error)
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
                errorHandler.handle(error)
                return nil
            }
        }
    }

    /// 清空所有 mod 缓存（静默版本）
    func clearSilently() {
        do {
            try queue.sync {
                try ensureInitialized()
                try modCacheDB.clearAllModCaches()
            }
        } catch {
            errorHandler.handle(error)
        }
    }
}
