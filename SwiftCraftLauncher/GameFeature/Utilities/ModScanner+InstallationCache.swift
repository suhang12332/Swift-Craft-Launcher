import Foundation

// MARK: - Mod Installation Cache
extension ModScanner {
    /// 按目录绝对路径缓存该目录下所有文件 hash 集合
    actor DirectoryHashCache {
        static let shared = DirectoryHashCache()

        private var cache: [String: Set<String>] = [:] // key: standardized directory path

        private init() {}

        func get(for directory: URL) -> Set<String>? {
            cache[directory.standardizedFileURL.path]
        }

        func set(_ hashes: Set<String>, for directory: URL) {
            cache[directory.standardizedFileURL.path] = hashes
        }

        func remove(for directory: URL) {
            cache.removeValue(forKey: directory.standardizedFileURL.path)
        }
    }

    actor ModInstallationCache {
        static let shared = ModInstallationCache()

        private var cache: [String: Set<String>] = [:]

        private init() {}

        func addHash(_ hash: String, to gameName: String) {
            if var cached = cache[gameName] {
                cached.insert(hash)
                cache[gameName] = cached
            } else {
                // 如果缓存不存在，创建一个新的集合
                cache[gameName] = [hash]
            }
        }

        func removeHash(_ hash: String, from gameName: String) {
            if var cached = cache[gameName] {
                cached.remove(hash)
                cache[gameName] = cached
            }
        }

        func getAllModsInstalled(for gameName: String) -> Set<String> {
            return cache[gameName] ?? Set<String>()
        }

        func hasCache(for gameName: String) -> Bool {
            return cache[gameName] != nil
        }

        func setAllModsInstalled(for gameName: String, hashes: Set<String>) {
            cache[gameName] = hashes
        }

        func removeGame(gameName: String) {
            cache.removeValue(forKey: gameName)
        }
    }

    func addModHash(_ hash: String, to gameName: String) {
        Task {
            await AppServices.modInstallationCache.addHash(hash, to: gameName)
        }
    }

    func removeModHash(_ hash: String, from gameName: String) {
        Task {
            await AppServices.modInstallationCache.removeHash(hash, from: gameName)
        }
    }

    func getAllModsInstalled(for gameName: String) async -> Set<String> {
        return await AppServices.modInstallationCache.getAllModsInstalled(for: gameName)
    }

    func clearModCache(for gameName: String) async {
        await AppServices.modInstallationCache.removeGame(gameName: gameName)
    }
}
