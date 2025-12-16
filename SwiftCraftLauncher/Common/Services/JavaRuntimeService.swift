import Foundation
import ZIPFoundation

/// Java运行时下载器
class JavaRuntimeService {
    static let shared = JavaRuntimeService()
    private let downloadSession = URLSession.shared

    // 进度回调 - 使用actor来确保线程安全
    private let progressActor = ProgressActor()
    // 取消检查回调 - 使用actor来确保线程安全
    private let cancelActor = CancelActor()

    // 公共接口方法
    func setProgressCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        Task {
            await progressActor.setCallback(callback)
        }
    }

    func setCancelCallback(_ callback: @escaping () -> Bool) {
        Task {
            await cancelActor.setCallback(callback)
        }
    }

    /// ARM平台专用版本的Zulu JDK配置
    private static let armJavaVersions: [String: URL] = [
        "jre-legacy": URLConfig.API.JavaRuntimeARM.jreLegacy,
        "java-runtime-alpha": URLConfig.API.JavaRuntimeARM.javaRuntimeAlpha,
        "java-runtime-beta": URLConfig.API.JavaRuntimeARM.javaRuntimeBeta,
    ]
    /// 解析Java运行时API并获取gamecore平台支持的版本名称
    func getGamecoreSupportedVersions() async throws -> [String] {
        let json = try await fetchJavaRuntimeAPI()
        guard let gamecore = json["gamecore"] as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "未找到gamecore平台数据",
                i18nKey: "error.validation.gamecore_not_found",
                level: .notification
            )
        }

        let versionNames = Array(gamecore.keys)
        return versionNames
    }
    /// 根据当前系统（macOS）和CPU架构获取对应的Java运行时数据
    func getMacJavaRuntimeData() async throws -> [String: Any] {
        let json = try await fetchJavaRuntimeAPI()
        let platform = getCurrentMacPlatform()
        guard let platformData = json[platform] as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "未找到\(platform)平台数据",
                i18nKey: "error.validation.platform_data_not_found",
                level: .notification
            )
        }

        return platformData
    }
    /// 根据传入的版本名称获取对应的Java运行时数据
    func getMacJavaRuntimeData(for version: String) async throws -> [[String: Any]] {
        let platformData = try await getMacJavaRuntimeData()
        guard let versionData = platformData[version] as? [[String: Any]] else {
            Logger.shared.error("版本 \(version) 的数据类型不正确，期望 [[String: Any]]，实际: \(type(of: platformData[version]))")
            throw GlobalError.validation(
                chineseMessage: "未找到版本 \(version) 的数据",
                i18nKey: "error.validation.version_data_not_found",
                level: .notification
            )
        }

        return versionData
    }
    /// 获取指定版本的manifest URL
    func getManifestURL(for version: String) async throws -> String {
        let versionData = try await getMacJavaRuntimeData(for: version)
        // 版本数据是一个数组，取第一个元素
        guard let firstVersion = versionData.first,
              let manifest = firstVersion["manifest"] as? [String: Any],
              let manifestURL = manifest["url"] as? String else {
            Logger.shared.error("无法解析版本 \(version) 的数据结构")
            throw GlobalError.validation(
                chineseMessage: "未找到版本 \(version) 的manifest URL",
                i18nKey: "error.validation.manifest_url_not_found",
                level: .notification
            )
        }

        Logger.shared.info("找到版本 \(version) 的manifest URL: \(manifestURL)")
        return manifestURL
    }
    /// 下载指定版本的Java运行时
    func downloadJavaRuntime(for version: String) async throws {
        // 检查是否为ARM平台专用版本（Zulu JDK）
        if let armVersionURL = Self.armJavaVersions[version] {
            try await downloadArmJavaRuntime(version: version, url: armVersionURL)
            return
        }

        let manifestURL = try await getManifestURL(for: version)
        // 下载manifest.json
        let manifestData = try await fetchDataFromURL(manifestURL)
        guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let files = manifest["files"] as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "解析manifest.json失败",
                i18nKey: "error.validation.manifest_parse_failed",
                level: .notification
            )
        }

        // 创建目标目录
        let targetDirectory = AppPaths.runtimeDirectory.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        // 计算总文件数 - 只统计type为file且实际需要下载的项目
        let totalFiles = files
            .compactMap { filePath, fileInfo -> Int? in
                guard let fileData = fileInfo as? [String: Any],
                      let fileType = fileData["type"] as? String,
                      fileType == "file" else {
                    return nil
                }

                // 检查文件是否已存在
                let localFilePath = targetDirectory.appendingPathComponent(filePath)
                let fileExists = FileManager.default.fileExists(atPath: localFilePath.path)

                // 只有不存在的文件才计入总数
                return fileExists ? nil : 1
            }
            .reduce(0, +)

        // 创建信号量控制并发数量
        let semaphore = AsyncSemaphore(
            value: GeneralSettingsManager.shared.concurrentDownloads
        )

        // 创建计数器用于进度跟踪
        let counter = Counter()

        // 使用并发下载所有文件
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (filePath, fileInfo) in files {
                group.addTask { [progressActor, cancelActor, self] in
                    // 检查是否应该取消
                    if await cancelActor.shouldCancel() {
                        Logger.shared.info("Java下载已被取消")
                        throw GlobalError.download(
                            chineseMessage: "下载已被取消",
                            i18nKey: "error.download.cancelled",
                            level: .notification
                        )
                    }

                    guard let fileData = fileInfo as? [String: Any],
                          let downloads = fileData["downloads"] as? [String: Any] else {
                        return
                    }

                    // 获取文件类型和可执行属性
                    let fileType = fileData["type"] as? String
                    let isExecutable = fileData["executable"] as? Bool ?? false

                    // 只使用raw格式
                    guard let raw = downloads["raw"] as? [String: Any] else {
                        Logger.shared.warning("文件 \(filePath) 没有RAW格式，跳过")
                        return
                    }

                    guard let fileURL = raw["url"] as? String else {
                        return
                    }

                    // 获取期望的SHA1值
                    let expectedSHA1 = raw["sha1"] as? String

                    // 确定本地文件路径
                    let localFilePath = targetDirectory.appendingPathComponent(filePath)

                    // 等待信号量
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }

                    // 检查文件是否已存在
                    let fileExistsBefore = FileManager.default.fileExists(atPath: localFilePath.path)

                    // 使用DownloadManager下载文件，它已经包含了文件存在性检查和SHA1校验
                    _ = try await DownloadManager.downloadFile(
                        urlString: fileURL,
                        destinationURL: localFilePath,
                        expectedSha1: expectedSHA1
                    )

                    // 如果文件类型为"file"且executable为true，给文件添加执行权限
                    if fileType == "file" && isExecutable {
                        try setExecutablePermission(for: localFilePath)
                    }

                    // 只有type为file的项目才计入完成文件数
                    // 并且只有在文件真正被下载时才增加计数（文件之前不存在）
                    if fileType == "file" && !fileExistsBefore {
                        // 验证文件确实存在且有内容
                        do {
                            let fileAttributes = try FileManager.default.attributesOfItem(atPath: localFilePath.path)
                            if let fileSize = fileAttributes[.size] as? Int64, fileSize > 0 {
                                let completed = await counter.increment()
                                await progressActor.callProgressUpdate(filePath, completed, totalFiles)
                            }
                        } catch {
                            Logger.shared.warning("无法验证文件 \(filePath) 的下载状态: \(error.localizedDescription)")
                        }
                    }
                }
            }
            try await group.waitForAll()
        }
    }
    /// 获取Java运行时API数据
    private func fetchJavaRuntimeAPI() async throws -> [String: Any] {
        let url = URLConfig.API.JavaRuntime.allRuntimes
        let data = try await fetchDataFromURL(url.absoluteString)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "解析JSON失败",
                i18nKey: "error.validation.json_parse_failed",
                level: .notification
            )
        }

        return json
    }

    /// 下载指定URL的数据
    /// - Parameter urlString: URL字符串
    /// - Returns: 下载的数据
    private func fetchDataFromURL(_ urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的URL",
                i18nKey: "error.validation.invalid_url",
                level: .notification
            )
        }

        let (data, response) = try await downloadSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "下载失败",
                i18nKey: "error.network.download_failed",
                level: .notification
            )
        }

        return data
    }
    /// 获取当前macOS平台标识
    private func getCurrentMacPlatform() -> String {
        #if arch(arm64)
        return "mac-os-arm64"
        #else
        return "mac-os"
        #endif
    }

    /// 为文件设置执行权限
    /// - Parameter filePath: 文件路径
    private func setExecutablePermission(for filePath: URL) throws {
        let fileManager = FileManager.default

        // 获取当前文件权限
        let currentAttributes = try fileManager.attributesOfItem(atPath: filePath.path)
        var currentPermissions = currentAttributes[.posixPermissions] as? UInt16 ?? 0o644

        // 添加执行权限 (owner, group, other)
        currentPermissions |= 0o111

        // 设置新的权限
        try fileManager.setAttributes([.posixPermissions: currentPermissions], ofItemAtPath: filePath.path)
    }

    /// 下载ARM平台特殊版本的Java运行时（从Zulu JDK）
    /// - Parameters:
    ///   - version: 版本名称
    ///   - url: 下载URL
    private func downloadArmJavaRuntime(version: String, url: URL) async throws {
        // 创建目标目录
        let targetDirectory = AppPaths.runtimeDirectory.appendingPathComponent(version)
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        // 下载zip文件到临时位置
        let tempZipPath = targetDirectory.appendingPathComponent("temp_java.zip")

        // 下载zip文件（带字节大小进度）
        try await downloadZipWithProgress(
            from: url,
            to: tempZipPath,
            fileName: "\(version).zip"
        )

        // 解压zip文件
        try await extractAndProcessArmJavaRuntime(
            zipPath: tempZipPath,
            targetDirectory: targetDirectory
        )

        // 更新进度 - 完成
        await progressActor.callProgressUpdate("Java运行时 \(version) 安装完成", 1, 1)
    }

    /// 解压并处理ARM Java运行时zip文件
    /// - Parameters:
    ///   - zipPath: zip文件路径
    ///   - targetDirectory: 目标目录
    private func extractAndProcessArmJavaRuntime(zipPath: URL, targetDirectory: URL) async throws {
        let fileManager = FileManager.default

        // 最终的jre.bundle路径
        let finalJreBundlePath = targetDirectory.appendingPathComponent("jre.bundle")

        // 如果目标位置已存在，先删除
        if fileManager.fileExists(atPath: finalJreBundlePath.path) {
            try fileManager.removeItem(at: finalJreBundlePath)
        }

        // 选择性解压zip文件中的JRE文件夹
        do {
            try extractSpecificFolderFromZip(
                zipPath: zipPath,
                destinationPath: finalJreBundlePath
            )
        } catch {
            Logger.shared.error("解压Java运行时失败: \(error.localizedDescription)")

            throw GlobalError.validation(
                chineseMessage: "解压Java运行时失败: \(error.localizedDescription)",
                i18nKey: "error.validation.extract_failed",
                level: .notification
            )
        }

        // 删除下载的压缩包
        try? fileManager.removeItem(at: zipPath)
    }

    /// 从zip文件中选择性解压zulu文件夹
    /// - Parameters:
    ///   - zipPath: zip文件路径
    ///   - destinationPath: 解压后的目标路径
    private func extractSpecificFolderFromZip(zipPath: URL, destinationPath: URL) throws {
        let fileManager = FileManager.default

        // 打开zip文件
        let archive: Archive
        do {
            archive = try Archive(url: zipPath, accessMode: .read)
        } catch {
            throw GlobalError.validation(
                chineseMessage: "无法打开zip文件: \(error.localizedDescription)",
                i18nKey: "error.validation.cannot_open_zip",
                level: .notification
            )
        }

        // 查找zulu文件夹的条目
        var targetFolderEntries: [Entry] = []
        var targetFolderPrefix: String?

        for entry in archive {
            let path = entry.path

            // 查找以"zulu-"开头的文件夹
            let pathComponents = path.split(separator: "/")

            for (index, component) in pathComponents.enumerated() {
                let componentStr = String(component)
                if componentStr.hasPrefix("zulu-") && componentStr.contains(".jre") {
                    if targetFolderPrefix == nil {
                        // 找到zulu文件夹，构建完整前缀路径
                        let prefixComponents = pathComponents[0...index]
                        targetFolderPrefix = prefixComponents.joined(separator: "/")
                        if let prefix = targetFolderPrefix, !prefix.isEmpty {
                            targetFolderPrefix = prefix + "/"
                        }
                    }
                    break
                }
            }

            // 如果找到了目标前缀，收集所有匹配的条目
            if let prefix = targetFolderPrefix, path.hasPrefix(prefix) {
                targetFolderEntries.append(entry)
            }
        }

        guard !targetFolderEntries.isEmpty, let prefix = targetFolderPrefix else {
            throw GlobalError.validation(
                chineseMessage: "在zip文件中未找到zulu文件夹",
                i18nKey: "error.validation.zulu_folder_not_found_in_zip",
                level: .notification
            )
        }

        // 解压目标文件夹的所有条目
        for entry in targetFolderEntries {
            // 计算相对于目标文件夹的路径
            let relativePath = String(entry.path.dropFirst(prefix.count))
            let outputPath = destinationPath.appendingPathComponent(relativePath)

            // 跳过符号链接条目
            if entry.type == .symlink {
                continue
            }

            do {
                // 如果是目录，创建目录
                if entry.type == .directory {
                    try fileManager.createDirectory(at: outputPath, withIntermediateDirectories: true)
                } else if entry.type == .file {
                    // 确保父目录存在
                    let parentDir = outputPath.deletingLastPathComponent()
                    try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                    // 解压文件
                    _ = try archive.extract(entry, to: outputPath)
                } else {
                    continue
                }
            } catch {
                // 检查具体的ZIPFoundation错误
                if let archiveError = error as? Archive.ArchiveError {
                    // 特殊处理符号链接错误
                    if String(describing: archiveError) == "uncontainedSymlink" {
                        continue // 跳过这个条目，继续处理下一个
                    }
                }

                // 对于其他错误，记录并抛出
                Logger.shared.error("解压失败: \(entry.path) - \(error.localizedDescription)")
                throw error
            }
        }
    }

    /// 下载ZIP文件并显示字节大小进度
    /// - Parameters:
    ///   - url: 下载URL
    ///   - destinationURL: 目标文件路径
    ///   - fileName: 显示的文件名
    private func downloadZipWithProgress(from url: URL, to destinationURL: URL, fileName: String) async throws {
        // 先获取文件大小
        let fileSize = try await getFileSize(from: url)

        // 设置初始进度
        await progressActor.callProgressUpdate(fileName, 0, Int(fileSize))

        // 创建进度跟踪器
        let progressCallback: (Int64, Int64) -> Void = { [progressActor] downloadedBytes, totalBytes in
            // 传递实际字节数用于字节大小进度显示
            Task {
                await progressActor.callProgressUpdate(fileName, Int(downloadedBytes), Int(totalBytes))
            }
        }
        let progressTracker = DownloadProgressTracker(totalSize: fileSize, progressCallback: progressCallback)

        // 创建URLSession配置
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: progressTracker, delegateQueue: nil)

        // 使用downloadTask方式下载，配合进度回调
        return try await withCheckedThrowingContinuation { continuation in
            // 设置完成回调
            progressTracker.completionHandler = { result in
                switch result {
                case .success(let tempURL):
                    do {
                        let fileManager = FileManager.default

                        // 如果目标文件已存在，先删除
                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }

                        // 移动临时文件到目标位置
                        try fileManager.moveItem(at: tempURL, to: destinationURL)
                        continuation.resume()
                    } catch {
                        Logger.shared.error("移动下载文件失败: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    Logger.shared.error("下载失败: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }

            // 创建下载任务并开始
            let downloadTask = session.downloadTask(with: url)
            downloadTask.resume()
        }
    }

    /// 获取远程文件大小
    private func getFileSize(from url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        // 使用统一的 API 客户端（HEAD 请求需要返回响应头）
        let (_, httpResponse) = try await APIClient.performRequestWithResponse(request: request)

        guard httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "无法获取文件大小 - HTTP状态码: \(httpResponse.statusCode)",
                i18nKey: "error.network.cannot_get_file_size",
                level: .notification
            )
        }

        guard let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let fileSize = Int64(contentLength) else {
            throw GlobalError.network(
                chineseMessage: "无法获取文件大小 - 缺少或无效的Content-Length头部",
                i18nKey: "error.network.cannot_get_file_size",
                level: .notification
            )
        }

        return fileSize
    }
}

/// 下载进度跟踪器
private class DownloadProgressTracker: NSObject, URLSessionDownloadDelegate {
    private let progressCallback: (Int64, Int64) -> Void
    private let totalFileSize: Int64
    var completionHandler: ((Result<URL, Error>) -> Void)?

    init(totalSize: Int64, progressCallback: @escaping (Int64, Int64) -> Void) {
        self.totalFileSize = totalSize
        self.progressCallback = progressCallback
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        // 使用真实的下载进度
        let actualTotalSize = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : totalFileSize

        if actualTotalSize > 0 {
            // 确保在主线程调用进度回调
            DispatchQueue.main.async { [weak self] in
                self?.progressCallback(totalBytesWritten, actualTotalSize)
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 调用完成回调
        completionHandler?(.success(location))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler?(.failure(error))
        }
    }
}

/// 线程安全的计数器，用于跟踪并发下载进度
private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}

/// 线程安全的进度回调actor
private actor ProgressActor {
    private var callback: ((String, Int, Int) -> Void)?

    func setCallback(_ callback: @escaping (String, Int, Int) -> Void) {
        self.callback = callback
    }

    func callProgressUpdate(_ fileName: String, _ completed: Int, _ total: Int) {
        callback?(fileName, completed, total)
    }
}

/// 线程安全的取消检查actor
private actor CancelActor {
    private var callback: (() -> Bool)?

    func setCallback(_ callback: @escaping () -> Bool) {
        self.callback = callback
    }

    func shouldCancel() -> Bool {
        return callback?() ?? false
    }
}
