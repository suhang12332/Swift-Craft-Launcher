//
//  ModPackDependencyInstaller.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/3.
//

import Foundation

/// 整合包依赖安装服务
/// 负责安装整合包中定义的所有必需依赖
struct ModPackDependencyInstaller {
    
    // MARK: - Download Type
    enum DownloadType {
        case files
        case dependencies
        case overrides
    }
    
    // MARK: - Main Installation Method
    
    /// 安装整合包版本的所有必需依赖
    /// - Parameters:
    ///   - indexInfo: 解析出的整合包索引信息
    ///   - gameInfo: 游戏信息
    ///   - extractedPath: 解压后的路径
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 是否安装成功
    static func installVersionDependencies(
        indexInfo: ModrinthIndexInfo,
        gameInfo: GameVersionInfo,
        extractedPath: URL? = nil,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)? = nil
    ) async -> Bool {
        Logger.shared.info("开始安装整合包依赖: \(indexInfo.modPackName)")
        
        // 获取资源目录
        guard let resourceDir = AppPaths.profileDirectory(gameName: gameInfo.gameName) else {
            Logger.shared.error("无法获取资源目录")
            return false
        }
        
        // 并发执行文件和依赖的安装
        async let filesResult = installModPackFiles(
            files: indexInfo.files,
            resourceDir: resourceDir,
            onProgressUpdate: onProgressUpdate
        )
        
        async let dependenciesResult = installModPackDependencies(
            dependencies: indexInfo.dependencies,
            gameInfo: gameInfo,
            resourceDir: resourceDir,
            onProgressUpdate: onProgressUpdate
        )
        
        // 等待两个任务完成
        let (filesSuccess, dependenciesSuccess) = await (filesResult, dependenciesResult)
        
        // 检查结果
        if !filesSuccess {
            Logger.shared.error("整合包文件安装失败")
            return false
        }
        
        if !dependenciesSuccess {
            Logger.shared.error("整合包依赖安装失败")
            return false
        }
        
        // 3. 处理 overrides 文件夹（这个必须在文件和依赖都完成后进行）
        if let extractedPath = extractedPath {
            guard await installOverrides(
                extractedPath: extractedPath,
                resourceDir: resourceDir,
                onProgressUpdate: onProgressUpdate
            ) else {
                Logger.shared.error("overrides 文件夹处理失败")
                return false
            }
        }
        
        Logger.shared.info("整合包依赖安装完成")
        return true
    }
    
    // MARK: - File Installation
    
    /// 安装整合包文件
    /// - Parameters:
    ///   - files: 文件列表
    ///   - resourceDir: 资源目录
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 是否安装成功
    private static func installModPackFiles(
        files: [ModrinthIndexFile],
        resourceDir: URL,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?
    ) async -> Bool {
        Logger.shared.info("开始安装整合包文件，共 \(files.count) 个文件")
        
        // 过滤出需要下载的文件
        let filesToDownload = filterDownloadableFiles(files)
        Logger.shared.info("需要下载的文件数量: \(filesToDownload.count)")
        
        // 通知开始下载
        onProgressUpdate?("开始下载整合包文件", 0, filesToDownload.count, .files)
        
        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(value: GameSettingsManager.shared.concurrentDownloads)
        
        // 使用计数器跟踪完成的文件数量
        let completedCount = ModPackCounter()
        
        // 使用 TaskGroup 并发下载文件
        let results = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, file) in filesToDownload.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    let success = await downloadSingleFile(file: file, resourceDir: resourceDir)
                    
                    // 更新进度
                    if success {
                        let currentCount = completedCount.increment()
                        onProgressUpdate?(file.path, currentCount, filesToDownload.count, .files)
                    }
                    
                    return (index, success)
                }
            }
            
            // 收集结果
            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 } // 按索引排序
        }
        
        // 检查所有下载是否成功
        let successCount = results.filter { $0.1 }.count
        let failedCount = results.count - successCount
        
        if failedCount > 0 {
            Logger.shared.error("有 \(failedCount) 个文件下载失败")
            return false
        }
        
        // 通知下载完成
        onProgressUpdate?("整合包文件下载完成", filesToDownload.count, filesToDownload.count, .files)
        
        Logger.shared.info("整合包文件安装完成")
        return true
    }
    
    /// 过滤可下载的文件
    /// - Parameter files: 文件列表
    /// - Returns: 过滤后的文件列表
    private static func filterDownloadableFiles(_ files: [ModrinthIndexFile]) -> [ModrinthIndexFile] {
        return files.filter { file in
            // 只检查 client 字段，忽略 server
            if let env = file.env, let client = env.client, client.lowercased() == "unsupported" {
                Logger.shared.info("跳过不支持的文件: \(file.path)")
                return false
            }
            return true
        }
    }
    
    /// 下载单个文件
    /// - Parameters:
    ///   - file: 文件信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否下载成功
    private static func downloadSingleFile(file: ModrinthIndexFile, resourceDir: URL) async -> Bool {
        guard let urlString = file.downloads.first, !urlString.isEmpty else {
            Logger.shared.error("文件无可用下载链接: \(file.path)")
            return false
        }
        
        do {
            let downloadedFile = try await DownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: resourceDir.appendingPathComponent(file.path),
                expectedSha1: file.hashes["sha1"]
            )
            
            // 保存到缓存
            if let hash = ModScanner.sha1Hash(of: downloadedFile) {
                // 使用fetchModrinthDetail获取真实的项目详情
                await withCheckedContinuation { continuation in
                    ModrinthService.fetchModrinthDetail(by: hash) { projectDetail in
                        if let detail = projectDetail {
                            // 添加文件信息到detail
                            var detailWithFile = detail
                            detailWithFile.fileName = (file.path as NSString).lastPathComponent
                            detailWithFile.type = "mod"
                            
                            // 存入缓存
                            ModScanner.shared.saveToCache(hash: hash, detail: detailWithFile)
                            Logger.shared.info("已缓存文件详情: \(file.path)")
                        } else {
                            Logger.shared.warning("无法获取文件详情: \(file.path)")
                        }
                        continuation.resume()
                    }
                }
            }
            
            Logger.shared.info("已下载文件: \(file.path)")
            return true
        } catch {
            Logger.shared.error("下载文件失败: \(file.path), 错误: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Dependency Installation
    
    /// 安装整合包依赖
    /// - Parameters:
    ///   - dependencies: 依赖列表
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 是否安装成功
    private static func installModPackDependencies(
        dependencies: [ModrinthIndexProjectDependency],
        gameInfo: GameVersionInfo,
        resourceDir: URL,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?
    ) async -> Bool {
        // 过滤出必需的依赖
        let requiredDependencies = dependencies.filter { $0.dependencyType == "required" }
        
        Logger.shared.info("开始安装整合包依赖，共 \(requiredDependencies.count) 个必需依赖")
        
        // 通知开始下载
        onProgressUpdate?("开始安装整合包依赖", 0, requiredDependencies.count, .dependencies)
        
        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(value: GameSettingsManager.shared.concurrentDownloads)
        
        // 使用计数器跟踪完成的依赖数量
        let completedCount = ModPackCounter()
        
        // 使用 TaskGroup 并发安装依赖
        let results = await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, dep) in requiredDependencies.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    // 检查是否需要跳过
                    if shouldSkipDependency(dep: dep, gameInfo: gameInfo, resourceDir: resourceDir) {
                        // 跳过也更新进度
                        let currentCount = completedCount.increment()
                        onProgressUpdate?("跳过已安装的依赖", currentCount, requiredDependencies.count, .dependencies)
                        return (index, true) // 跳过视为成功
                    }
                    
                    // 安装依赖
                    let success = await installDependency(dep: dep, gameInfo: gameInfo, resourceDir: resourceDir)
                    
                    // 更新进度
                    if success {
                        let currentCount = completedCount.increment()
                        let dependencyName = dep.projectId ?? "未知依赖"
                        onProgressUpdate?(dependencyName, currentCount, requiredDependencies.count, .dependencies)
                    }
                    
                    return (index, success)
                }
            }
            
            // 收集结果
            var results: [(Int, Bool)] = []
            for await result in group {
                results.append(result)
            }
            return results.sorted { $0.0 < $1.0 } // 按索引排序
        }
        
        // 检查所有安装是否成功
        let successCount = results.filter { $0.1 }.count
        let failedCount = results.count - successCount
        
        if failedCount > 0 {
            Logger.shared.error("有 \(failedCount) 个依赖安装失败")
            return false
        }
        
        // 通知安装完成
        onProgressUpdate?("整合包依赖安装完成", requiredDependencies.count, requiredDependencies.count, .dependencies)
        
        Logger.shared.info("整合包依赖安装完成")
        return true
    }
    
    /// 检查是否需要跳过依赖
    /// - Parameters:
    ///   - dep: 依赖信息
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否需要跳过
    private static func shouldSkipDependency(
        dep: ModrinthIndexProjectDependency,
        gameInfo: GameVersionInfo,
        resourceDir: URL
    ) -> Bool {
        // 跳过 Fabric API 在 Quilt 上的安装
        if dep.projectId == "P7dR8mSH" && gameInfo.modLoader.lowercased() == "quilt" {
            Logger.shared.info("跳过 Fabric API 在 Quilt 上的安装")
            return true
        }
        
        // 检查是否已安装
        if let projectId = dep.projectId,
           ModScanner.shared.isModInstalledSync(projectId: projectId, in: resourceDir) {
            Logger.shared.info("依赖已安装，跳过: \(projectId)")
            return true
        }
        
        return false
    }
    
    // MARK: - Overrides Installation
    
    /// 安装 overrides 文件夹内容
    /// - Parameters:
    ///   - extractedPath: 解压后的路径
    ///   - resourceDir: 资源目录
    ///   - onProgressUpdate: 进度更新回调
    /// - Returns: 是否安装成功
    private static func installOverrides(
        extractedPath: URL,
        resourceDir: URL,
        onProgressUpdate: ((String, Int, Int, DownloadType) -> Void)?
    ) async -> Bool {
        let overridesPath = extractedPath.appendingPathComponent("overrides")
        
        // 检查 overrides 文件夹是否存在
        guard FileManager.default.fileExists(atPath: overridesPath.path) else {
            Logger.shared.info("overrides 文件夹不存在，跳过处理")
            return true
        }
        
        Logger.shared.info("开始处理 overrides 文件夹: \(overridesPath.path)")
        
        do {
            // 获取 overrides 文件夹中的所有内容
            let contents = try FileManager.default.contentsOfDirectory(
                at: overridesPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            Logger.shared.info("overrides 文件夹包含 \(contents.count) 个项目")
            
            // 通知开始处理
            onProgressUpdate?("开始处理 overrides 文件夹", 0, contents.count, .overrides)
            
            // 逐个处理文件/文件夹
            for (index, item) in contents.enumerated() {
                let itemName = item.lastPathComponent
                let destinationPath = resourceDir.appendingPathComponent(itemName)
                
                try await processOverrideItem(item: item, destinationPath: destinationPath, itemName: itemName)
                
                // 处理完成后更新进度
                onProgressUpdate?("正在处理: \(itemName)", index + 1, contents.count, .overrides)
            }
            
            // 通知处理完成
            onProgressUpdate?("overrides 文件夹处理完成", contents.count, contents.count, .overrides)
            
            Logger.shared.info("overrides 文件夹处理完成")
            return true
            
        } catch {
            Logger.shared.error("处理 overrides 文件夹失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 处理单个 overrides 项目
    /// - Parameters:
    ///   - item: 源项目
    ///   - destinationPath: 目标路径
    ///   - itemName: 项目名称
    private static func processOverrideItem(item: URL, destinationPath: URL, itemName: String) async throws {
        if FileManager.default.fileExists(atPath: destinationPath.path) {
            // 如果目标路径存在，检查是否为目录
            let itemAttributes = try FileManager.default.attributesOfItem(atPath: item.path)
            let destinationAttributes = try FileManager.default.attributesOfItem(atPath: destinationPath.path)
            
            let isSourceDirectory = (itemAttributes[.type] as? FileAttributeType) == .typeDirectory
            let isDestinationDirectory = (destinationAttributes[.type] as? FileAttributeType) == .typeDirectory
            
            if isSourceDirectory && isDestinationDirectory {
                // 如果都是目录，递归合并
                try await mergeDirectories(source: item, destination: destinationPath)
                Logger.shared.info("已合并目录: \(itemName)")
            } else if !isSourceDirectory && !isDestinationDirectory {
                // 如果都是文件，覆盖
                try FileManager.default.removeItem(at: destinationPath)
                try FileManager.default.moveItem(at: item, to: destinationPath)
                Logger.shared.info("已覆盖文件: \(itemName)")
            } else {
                // 类型不匹配，跳过
                Logger.shared.warning("跳过类型不匹配的项目: \(itemName)")
            }
        } else {
            // 目标路径不存在，直接移动
            try FileManager.default.moveItem(at: item, to: destinationPath)
            Logger.shared.info("已移动: \(itemName)")
        }
    }
    
    /// 递归合并目录
    /// - Parameters:
    ///   - source: 源目录
    ///   - destination: 目标目录
    private static func mergeDirectories(source: URL, destination: URL) async throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        for item in contents {
            let itemName = item.lastPathComponent
            let destinationItem = destination.appendingPathComponent(itemName)
            
            if FileManager.default.fileExists(atPath: destinationItem.path) {
                // 目标路径存在，检查类型
                let itemAttributes = try FileManager.default.attributesOfItem(atPath: item.path)
                let destinationAttributes = try FileManager.default.attributesOfItem(atPath: destinationItem.path)
                
                let isSourceDirectory = (itemAttributes[.type] as? FileAttributeType) == .typeDirectory
                let isDestinationDirectory = (destinationAttributes[.type] as? FileAttributeType) == .typeDirectory
                
                if isSourceDirectory && isDestinationDirectory {
                    // 递归合并子目录
                    try await mergeDirectories(source: item, destination: destinationItem)
                } else if !isSourceDirectory && !isDestinationDirectory {
                    // 覆盖文件
                    try FileManager.default.removeItem(at: destinationItem)
                    try FileManager.default.moveItem(at: item, to: destinationItem)
                }
                // 类型不匹配的情况跳过
            } else {
                // 目标路径不存在，直接移动
                try FileManager.default.moveItem(at: item, to: destinationItem)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 安装单个依赖
    /// - Parameters:
    ///   - dep: 依赖信息
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否安装成功
    private static func installDependency(
        dep: ModrinthIndexProjectDependency,
        gameInfo: GameVersionInfo,
        resourceDir: URL
    ) async -> Bool {
        guard let projectId = dep.projectId else {
            Logger.shared.error("依赖缺少项目ID")
            return false
        }
        
        do {
            if let versionId = dep.versionId {
                // 如果有指定版本ID，直接使用该版本
                return await addProjectFromVersion(
                    projectId: projectId,
                    versionId: versionId,
                    gameInfo: gameInfo,
                    resourceDir: resourceDir
                )
            } else {
                // 如果没有指定版本ID，获取最新兼容版本
                return await addProjectFromLatestVersion(
                    projectId: projectId,
                    gameInfo: gameInfo,
                    resourceDir: resourceDir
                )
            }
        } catch {
            Logger.shared.error("安装依赖失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从指定版本安装项目
    /// - Parameters:
    ///   - projectId: 项目ID
    ///   - versionId: 版本ID
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否安装成功
    private static func addProjectFromVersion(
        projectId: String,
        versionId: String,
        gameInfo: GameVersionInfo,
        resourceDir: URL
    ) async -> Bool {
        do {
            // 获取版本详情
            let version = try await ModrinthService.fetchProjectVersionThrowing(id: versionId)
            
            // 检查版本兼容性
            guard version.gameVersions.contains(gameInfo.gameVersion) &&
                  version.loaders.contains(gameInfo.modLoader) else {
                Logger.shared.error("版本不兼容: \(versionId)")
                return false
            }
            
            // 获取项目详情
            let projectDetail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId)
            
            // 下载并安装
            return await downloadAndInstallVersion(
                version: version,
                projectDetail: projectDetail,
                gameInfo: gameInfo,
                resourceDir: resourceDir
            )
            
        } catch {
            Logger.shared.error("获取版本详情失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 从最新兼容版本安装项目
    /// - Parameters:
    ///   - projectId: 项目ID
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否安装成功
    private static func addProjectFromLatestVersion(
        projectId: String,
        gameInfo: GameVersionInfo,
        resourceDir: URL
    ) async -> Bool {
        do {
            // 获取项目详情
            let projectDetail = try await ModrinthService.fetchProjectDetailsThrowing(id: projectId)
            
            // 获取所有版本
            let versions = try await ModrinthService.fetchProjectVersionsThrowing(id: projectId)
            
            // 按发布日期排序，找到最新兼容版本
            let sortedVersions = versions.sorted { $0.datePublished > $1.datePublished }
            
            let latestCompatibleVersion = sortedVersions.first { version in
                version.gameVersions.contains(gameInfo.gameVersion) &&
                version.loaders.contains(gameInfo.modLoader)
            }
            
            guard let latestVersion = latestCompatibleVersion else {
                Logger.shared.error("未找到兼容版本: \(projectId)")
                return false
            }
            
            // 下载并安装
            return await downloadAndInstallVersion(
                version: latestVersion,
                projectDetail: projectDetail,
                gameInfo: gameInfo,
                resourceDir: resourceDir
            )
            
        } catch {
            Logger.shared.error("获取项目详情失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 下载并安装版本
    /// - Parameters:
    ///   - version: 版本信息
    ///   - projectDetail: 项目详情
    ///   - gameInfo: 游戏信息
    ///   - resourceDir: 资源目录
    /// - Returns: 是否安装成功
    private static func downloadAndInstallVersion(
        version: ModrinthProjectDetailVersion,
        projectDetail: ModrinthProjectDetail,
        gameInfo: GameVersionInfo,
        resourceDir: URL
    ) async -> Bool {
        do {
            // 获取主文件
            guard let primaryFile = ModrinthService.filterPrimaryFiles(from: version.files) else {
                Logger.shared.error("未找到主文件: \(version.id)")
                return false
            }
            
            // 下载文件
            let downloadedFile = try await DownloadManager.downloadResource(
                for: gameInfo,
                urlString: primaryFile.url,
                resourceType: "mod",
                expectedSha1: primaryFile.hashes.sha1
            )
            
            // 保存到缓存
            if let hash = ModScanner.sha1Hash(of: downloadedFile) {
                // 使用传入的项目详情创建缓存
                var detailWithFile = projectDetail
                detailWithFile.fileName = primaryFile.filename
                detailWithFile.type = "mod"
                ModScanner.shared.saveToCache(hash: hash, detail: detailWithFile)
            }
            
            Logger.shared.info("依赖下载成功: \(version.name)")
            return true
            
        } catch {
            Logger.shared.error("下载依赖失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Thread-safe Counter
final class ModPackCounter {
    private var count = 0
    private let lock = NSLock()
    
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        count = 0
    }
} 
