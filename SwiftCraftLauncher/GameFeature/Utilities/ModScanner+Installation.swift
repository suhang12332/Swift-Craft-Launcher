import Foundation

extension ModScanner {
    // MARK: - 安装状态检查

    /// 检查 mod 是否已安装
    func checkModInstalledCore(
        hash: String,
        gameName: String
    ) async -> Bool {
        let cachedMods = await AppServices.modInstallationCache.getAllModsInstalled(for: gameName)
        return cachedMods.contains(hash)
    }

    /// 通用：根据文件 hash 判断资源是否已安装（适用于非 mod 资源目录）
    /// - Parameters:
    ///   - hash: 资源文件的 sha1 哈希
    ///   - dir: 资源所在的本地目录（例如 resourcepack / shader / datapack 目录）
    /// - Returns: 是否已安装（基于本地目录 hash 缓存）
    func isResourceInstalledByHash(
        _ hash: String,
        in dir: URL
    ) async -> Bool {
        do {
            let hashes = try await scanAllDetailIdsThrowing(in: dir)
            return hashes.contains(hash)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查资源安装状态失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（静默版本）
    public func localModDetails(in dir: URL) -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        do {
            return try localModDetailsThrowing(in: dir)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("获取本地 mod 详情失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return []
        }
    }

    /// 获取目录下所有 jar/zip 文件及其 hash、缓存 detail（抛出异常版本）
    public func localModDetailsThrowing(in dir: URL) throws -> [(
        file: URL, hash: String, detail: ModrinthProjectDetail?
    )] {
        return try scanDirectoryForDetails(in: dir)
    }

    /// 同步：仅查缓存（通过文件hash检查）
    func isModInstalledSync(hash: String, in modsDir: URL) -> Bool {
        do {
            return try isModInstalledSyncThrowing(
                hash: hash,
                in: modsDir
            )
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("检查 mod 安装状态失败: \(globalError.chineseMessage)")
            errorHandler.handle(globalError)
            return false
        }
    }

    /// 同步：仅查缓存（抛出异常版本）
    func isModInstalledSyncThrowing(
        hash: String,
        in modsDir: URL
    ) throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        // 使用 DispatchSemaphore 在同步函数中等待异步结果
        let semaphore = DispatchSemaphore(value: 0)
        var result = false

        Task {
            result = await checkModInstalledCore(hash: hash, gameName: gameName)
            semaphore.signal()
        }

        semaphore.wait()
        return result
    }

    /// 异步：仅查缓存（静默版本）
    func isModInstalled(
        hash: String,
        in modsDir: URL,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            do {
                let result = try await isModInstalledThrowing(
                    hash: hash,
                    in: modsDir
                )
                completion(result)
            } catch {
                let globalError = GlobalError.from(error)
                Logger.shared.error(
                    "检查 mod 安装状态失败: \(globalError.chineseMessage)"
                )
                errorHandler.handle(globalError)
                completion(false)
            }
        }
    }

    /// 异步：仅查缓存（抛出异常版本）
    func isModInstalledThrowing(
        hash: String,
        in modsDir: URL
    ) async throws -> Bool {
        guard let gameName = extractGameName(from: modsDir) else {
            return false
        }

        return await checkModInstalledCore(hash: hash, gameName: gameName)
    }
}
