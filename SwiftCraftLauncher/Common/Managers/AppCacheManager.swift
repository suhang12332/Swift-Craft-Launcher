import Foundation

class AppCacheManager {
    static let shared = AppCacheManager()
    private let queue = DispatchQueue(label: "AppCacheManager.queue")

    private func fileURL(for namespace: String) throws -> URL {
        guard let dir = AppPaths.appCache else {
            throw GlobalError.configuration(
                chineseMessage: "无法获取缓存目录",
                i18nKey: "error.configuration.cache_directory_not_found",
                level: .popup
            )
        }
        
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "创建缓存目录失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.cache_directory_creation_failed",
                level: .notification
            )
        }
        
        return dir.appendingPathComponent("\(namespace).json")
    }

    // MARK: - Public API
    
    /// 设置缓存值
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - key: 键
    ///   - value: 值
    /// - Throws: GlobalError 当操作失败时
    func set<T: Codable>(namespace: String, key: String, value: T) throws {
        try queue.sync {
            var nsDict = try loadNamespace(namespace)
            
            do {
                let data = try JSONEncoder().encode(value)
                nsDict[key] = data
                try saveNamespace(namespace, dict: nsDict)
            } catch {
                throw GlobalError.validation(
                    chineseMessage: "缓存数据编码失败: \(error.localizedDescription)",
                    i18nKey: "error.validation.cache_data_encode_failed",
                    level: .notification
                )
            }
        }
    }
    
    /// 设置缓存值（静默版本，失败时记录错误但不抛出异常）
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - key: 键
    ///   - value: 值
    func setSilently<T: Codable>(namespace: String, key: String, value: T) {
        do {
            try set(namespace: namespace, key: key, value: value)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 获取缓存值
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - key: 键
    ///   - type: 期望的类型
    /// - Returns: 解码后的值，如果不存在或解码失败则返回 nil
    func get<T: Codable>(namespace: String, key: String, as type: T.Type) -> T? {
        return queue.sync {
            do {
                let nsDict = try loadNamespace(namespace)
                guard let data = nsDict[key] else { return nil }
                
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    GlobalErrorHandler.shared.handle(GlobalError.validation(
                        chineseMessage: "解码缓存数据失败: \(error.localizedDescription)",
                        i18nKey: "error.validation.cache_data_decode_failed",
                        level: .silent
                    ))
                    return nil
                }
            } catch {
                GlobalErrorHandler.shared.handle(error)
                return nil
            }
        }
    }

    /// 移除缓存项
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - key: 键
    /// - Throws: GlobalError 当操作失败时
    func remove(namespace: String, key: String) throws {
        try queue.sync {
            var nsDict = try loadNamespace(namespace)
            nsDict.removeValue(forKey: key)
            try saveNamespace(namespace, dict: nsDict)
        }
    }

    /// 移除缓存项（静默版本）
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - key: 键
    func removeSilently(namespace: String, key: String) {
        do {
            try remove(namespace: namespace, key: key)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 清空指定命名空间的缓存
    /// - Parameter namespace: 命名空间
    /// - Throws: GlobalError 当操作失败时
    func clear(namespace: String) throws {
        try queue.sync {
            try saveNamespace(namespace, dict: [:])
        }
    }

    /// 清空指定命名空间的缓存（静默版本）
    /// - Parameter namespace: 命名空间
    func clearSilently(namespace: String) {
        do {
            try clear(namespace: namespace)
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    /// 清空所有缓存
    /// - Throws: GlobalError 当操作失败时
    func clearAll() throws {
        try queue.sync {
            guard let dir = AppPaths.appCache else {
                throw GlobalError.configuration(
                    chineseMessage: "无法获取缓存目录",
                    i18nKey: "error.configuration.cache_directory_not_found",
                    level: .popup
                )
            }
            
            do {
                let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                for file in files where file.pathExtension == "json" {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                throw GlobalError.fileSystem(
                    chineseMessage: "清空缓存文件失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.cache_clear_failed",
                    level: .notification
                )
            }
        }
    }
    
    /// 清空所有缓存（静默版本）
    func clearAllSilently() {
        do {
            try clearAll()
        } catch {
            GlobalErrorHandler.shared.handle(error)
        }
    }

    // MARK: - Persistence
    
    /// 加载命名空间数据
    /// - Parameter namespace: 命名空间
    /// - Returns: 命名空间数据字典
    /// - Throws: GlobalError 当操作失败时
    private func loadNamespace(_ namespace: String) throws -> [String: Data] {
        let url = try fileURL(for: namespace)
        
        guard FileManager.default.fileExists(atPath: url.path) else { 
            return [:] 
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String: Data].self, from: data)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "读取缓存文件失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.cache_read_failed",
                level: .notification
            )
        }
    }

    /// 保存命名空间数据
    /// - Parameters:
    ///   - namespace: 命名空间
    ///   - dict: 要保存的数据字典
    /// - Throws: GlobalError 当操作失败时
    private func saveNamespace(_ namespace: String, dict: [String: Data]) throws {
        let url = try fileURL(for: namespace)
        
        do {
            let data = try JSONEncoder().encode(dict)
            try data.write(to: url)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "写入缓存文件失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.cache_write_failed",
                level: .notification
            )
        }
    }
} 

