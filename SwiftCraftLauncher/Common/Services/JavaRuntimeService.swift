import Foundation

/// Java运行时下载器
class JavaRuntimeService {
    static let shared = JavaRuntimeService()
    private let downloadSession = URLSession.shared
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
        Logger.shared.info("Gamecore支持的版本: \(versionNames)")
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

        Logger.shared.info("找到\(platform)平台的Java运行时数据")
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

        Logger.shared.info("找到版本 \(version) 的Java运行时数据")
        return versionData
    }
    /// 获取指定版本的manifest URL
    func getManifestURL(for version: String) async throws -> String {
        let versionData = try await getMacJavaRuntimeData(for: version)
        // 调试：打印版本数据的类型和内容
        Logger.shared.info("版本 \(version) 的数据类型: \(type(of: versionData))")
        Logger.shared.info("版本 \(version) 的数据内容: \(versionData)")
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
        let manifestURL = try await getManifestURL(for: version)
        Logger.shared.info("开始下载Java运行时版本: \(version)")
        // 下载manifest.json
        let manifestData = try await downloadFromURL(manifestURL)
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
        // 下载所有文件
        for (filePath, fileInfo) in files {
            guard let fileData = fileInfo as? [String: Any],
                  let downloads = fileData["downloads"] as? [String: Any] else {
                continue
            }

            // 获取文件类型和可执行属性
            let fileType = fileData["type"] as? String
            let isExecutable = fileData["executable"] as? Bool ?? false

            // 只使用raw格式
            guard let raw = downloads["raw"] as? [String: Any] else {
                Logger.shared.warning("文件 \(filePath) 没有RAW格式，跳过")
                continue
            }

            let downloadInfo = raw
            Logger.shared.info("使用RAW格式: \(filePath)")
            guard let fileURL = downloadInfo["url"] as? String else {
                continue
            }

            // 下载文件
            let downloadedData = try await downloadFromURL(fileURL)

            // 保存文件
            let localFilePath = targetDirectory.appendingPathComponent(filePath)
            let localDirectory = localFilePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: localDirectory, withIntermediateDirectories: true)
            // 直接保存RAW文件
            try downloadedData.write(to: localFilePath)
            Logger.shared.info("已下载RAW文件: \(filePath)")

            // 如果文件类型为"file"且executable为true，给文件添加执行权限
            if fileType == "file" && isExecutable {
                try setExecutablePermission(for: localFilePath)
                Logger.shared.info("已为可执行文件设置执行权限: \(filePath)")
            }
        }

        Logger.shared.info("Java运行时版本 \(version) 下载完成")
    }
    /// 下载指定URL的内容
    private func downloadFromURL(_ urlString: String) async throws -> Data {
        Logger.shared.info("开始下载: \(urlString)")
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

        Logger.shared.info("下载完成: \(urlString)")
        return data
    }
    /// 获取Java运行时API数据
    private func fetchJavaRuntimeAPI() async throws -> [String: Any] {
        let url = URLConfig.API.JavaRuntime.allRuntimes
        Logger.shared.info("开始下载: \(url.absoluteString)")
        let (data, response) = try await downloadSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GlobalError.network(
                chineseMessage: "下载失败",
                i18nKey: "error.network.download_failed",
                level: .notification
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GlobalError.validation(
                chineseMessage: "解析JSON失败",
                i18nKey: "error.validation.json_parse_failed",
                level: .notification
            )
        }

        return json
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
}
