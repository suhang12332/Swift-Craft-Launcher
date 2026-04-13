import Foundation
import CommonCrypto

enum DownloadManager {
    enum ResourceType: String {
        case mod, datapack, shader, resourcepack

        var folderName: String {
            switch self {
            case .mod: return AppConstants.DirectoryNames.mods
            case .datapack: return AppConstants.DirectoryNames.datapacks
            case .shader: return AppConstants.DirectoryNames.shaderpacks
            case .resourcepack: return AppConstants.DirectoryNames.resourcepacks
            }
        }

        init?(from string: String) {
            // 优化：使用 caseInsensitiveCompare 避免创建临时小写字符串
            let lowercased = string.lowercased()
            switch lowercased {
            case Self.mod.rawValue: self = .mod
            case Self.datapack.rawValue: self = .datapack
            case Self.shader.rawValue: self = .shader
            case Self.resourcepack.rawValue: self = .resourcepack
            default: return nil
            }
        }
    }

    /// 下载资源文件
    /// - Parameters:
    ///   - game: 游戏信息
    ///   - urlString: 下载地址
    ///   - resourceType: 资源类型（如 "mod", "datapack", "shader", "resourcepack"）
    ///   - expectedSha1: 预期 SHA1 值
    /// - Returns: 下载到的本地文件 URL
    /// - Throws: GlobalError 当操作失败时
    static func downloadResource(for game: GameVersionInfo, urlString: String, resourceType: String, expectedSha1: String? = nil) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的下载地址",
                i18nKey: "error.validation.invalid_download_url",
                level: .notification
            )
        }

        guard let type = ResourceType(from: resourceType) else {
            throw GlobalError.resource(
                chineseMessage: "未知的资源类型",
                i18nKey: "error.resource.unknown_type",
                level: .notification
            )
        }

        let resourceDir: URL? = {
            switch type {
            case .mod:
                return AppPaths.modsDirectory(gameName: game.gameName)
            case .datapack:
                // 优化：缓存小写路径组件，避免重复创建
                let lowercasedPath = url.lastPathComponent.lowercased()
                if lowercasedPath.hasSuffix(".\(AppConstants.FileExtensions.jar)") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.datapacksDirectory(gameName: game.gameName)
            case .shader:
                return AppPaths.shaderpacksDirectory(gameName: game.gameName)
            case .resourcepack:
                // 优化：缓存小写路径组件，避免重复创建
                let lowercasedPath = url.lastPathComponent.lowercased()
                if lowercasedPath.hasSuffix(".\(AppConstants.FileExtensions.jar)") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.resourcepacksDirectory(gameName: game.gameName)
            }
        }()

        guard let resourceDirUnwrapped = resourceDir else {
            throw GlobalError.resource(
                chineseMessage: "无法获取资源目录",
                i18nKey: "error.resource.directory_not_found",
                level: .notification
            )
        }

        let destURL = resourceDirUnwrapped.appendingPathComponent(url.lastPathComponent)
        // 优化：直接传递已创建的 URL，避免在 downloadFile 中重复创建
        return try await downloadFile(url: url, destinationURL: destURL, expectedSha1: expectedSha1)
    }

    /// 通用下载文件到指定路径（不做任何目录结构拼接）
    /// - Parameters:
    ///   - urlString: 下载地址（字符串形式）
    ///   - destinationURL: 目标文件路径
    ///   - expectedSha1: 预期 SHA1 值
    /// - Returns: 下载到的本地文件 URL
    /// - Throws: GlobalError 当操作失败时
    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil
    ) async throws -> URL {
        let url = try FileDownloadCore.parseURL(from: urlString)
        return try await downloadFile(url: url, destinationURL: destinationURL, expectedSha1: expectedSha1)
    }

    /// 通用下载文件到指定路径（内部方法，接受 URL 对象）
    /// - Parameters:
    ///   - url: 下载地址（URL 对象）
    ///   - destinationURL: 目标文件路径
    ///   - expectedSha1: 预期 SHA1 值
    /// - Returns: 下载到的本地文件 URL
    /// - Throws: GlobalError 当操作失败时
    private static func downloadFile(
        url: URL,
        destinationURL: URL,
        expectedSha1: String? = nil
    ) async throws -> URL {
        let finalURL = FileDownloadCore.normalizedDownloadURL(from: url)

        let fileManager = FileManager.default

        try FileDownloadCore.ensureParentDirectory(for: destinationURL, fileManager: fileManager)

        if FileDownloadCore.existingFileSizeIfReusable(
            at: destinationURL,
            expectedSha1: expectedSha1,
            fileManager: fileManager
        ) != nil {
            return destinationURL
        }

        // 下载文件到临时位置（异步操作在 autoreleasepool 外部）
        do {
            let (tempFileURL, response) = try await URLSession.shared.download(from: finalURL)
            defer {
                // 确保临时文件被清理
                try? fileManager.removeItem(at: tempFileURL)
            }

            // 优化：直接检查状态码，减少中间变量
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "HTTP 请求失败",
                    i18nKey: "error.download.http_status_error",
                    level: .notification
                )
            }

            try FileDownloadCore.validateSHA1IfNeeded(for: tempFileURL, expectedSha1: expectedSha1)
            try FileDownloadCore.moveDownloadedFile(from: tempFileURL, to: destinationURL, fileManager: fileManager)

            return destinationURL
        } catch {
            // 转换错误为 GlobalError
            if let globalError = error as? GlobalError {
                throw globalError
            } else if error is URLError {
                throw GlobalError.download(
                    chineseMessage: "网络请求失败",
                    i18nKey: "error.download.network_request_failed",
                    level: .notification
                )
            } else {
                throw GlobalError.download(
                    chineseMessage: "下载失败",
                    i18nKey: "error.download.general_failure",
                    level: .notification
                )
            }
        }
    }

    /// 计算文件的 SHA1 哈希值
    /// - Parameter url: 文件路径
    /// - Returns: SHA1 哈希字符串
    /// - Throws: GlobalError 当操作失败时
    static func calculateFileSHA1(at url: URL) throws -> String {
        return try SHA1Calculator.sha1(ofFileAt: url)
    }

    /// 下载 URL 对应的原始数据
    /// - Parameter url: 下载地址
    /// - Returns: 下载到的数据
    /// - Throws: GlobalError 当操作失败时
    static func downloadData(from url: URL) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "HTTP 请求失败",
                    i18nKey: "error.download.http_status_error",
                    level: .notification
                )
            }
            return data
        } catch {
            if let globalError = error as? GlobalError {
                throw globalError
            } else if error is URLError {
                throw GlobalError.download(
                    chineseMessage: "网络请求失败",
                    i18nKey: "error.download.network_request_failed",
                    level: .notification
                )
            } else {
                throw GlobalError.download(
                    chineseMessage: "下载失败",
                    i18nKey: "error.download.general_failure",
                    level: .notification
                )
            }
        }
    }
}
