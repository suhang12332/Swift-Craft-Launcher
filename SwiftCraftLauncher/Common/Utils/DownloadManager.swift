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
            case "mod": self = .mod
            case "datapack": self = .datapack
            case "shader": self = .shader
            case "resourcepack": self = .resourcepack
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

    // 常量字符串，避免重复创建
    private static let githubPrefix = "https://github.com/"
    private static let rawGithubPrefix = "https://raw.githubusercontent.com/"
    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

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
        // 优化：先创建 URL，然后调用内部方法
        let url: URL = try autoreleasepool {
            guard let url = URL(string: urlString) else {
                throw GlobalError.validation(
                    chineseMessage: "无效的下载地址",
                    i18nKey: "error.validation.invalid_download_url",
                    level: .notification
                )
            }
            return url
        }
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
        // 优化：在同步部分使用 autoreleasepool 及时释放临时对象
        // 优化：直接使用 URL，避免同时存储 String 和 URL（节省内存）
        let finalURL: URL = autoreleasepool {
            // 优化：直接使用 URL 的 host 属性检查，避免转换为 String
            let needsProxy: Bool
            if let host = url.host {
                needsProxy = host == githubHost || host == rawGithubHost
            } else {
                // 如果没有 host，检查 absoluteString（可能是相对路径）
                let absoluteString = url.absoluteString
                needsProxy = absoluteString.hasPrefix(githubPrefix) || absoluteString.hasPrefix(rawGithubPrefix)
            }

            if needsProxy {
                return URLConfig.applyGitProxyIfNeeded(url)
            } else {
                return url
            }
        }

        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "创建目标目录失败",
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification
            )
        }

        // 检查是否需要 SHA1 校验
        let shouldCheckSha1 = (expectedSha1?.isEmpty == false)

        // 如果文件已存在
        let destinationPath = destinationURL.path
        if fileManager.fileExists(atPath: destinationPath) {
            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                // 优化：使用 autoreleasepool 释放 SHA1 计算过程中的临时对象
                do {
                    let actualSha1 = try autoreleasepool {
                        try calculateFileSHA1(at: destinationURL)
                    }
                    if actualSha1 == expectedSha1 {
                        return destinationURL
                    }
                    // 如果校验失败，继续下载（不返回，继续执行下面的下载逻辑）
                } catch {
                    // 如果校验出错，继续下载（不中断）
                }
            } else {
                // 没有 SHA1 时直接跳过
                return destinationURL
            }
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

            // SHA1 校验（优化：使用 autoreleasepool）
            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                try autoreleasepool {
                    let actualSha1 = try calculateFileSHA1(at: tempFileURL)
                    if actualSha1 != expectedSha1 {
                        throw GlobalError.validation(
                            chineseMessage: "SHA1 校验失败",
                            i18nKey: "error.validation.sha1_check_failed",
                            level: .notification
                        )
                    }
                }
            }

            // 原子性地移动到最终位置
            if fileManager.fileExists(atPath: destinationURL.path) {
                // 先尝试直接替换
                try fileManager.replaceItem(at: destinationURL, withItemAt: tempFileURL, backupItemName: nil, options: [], resultingItemURL: nil)
            } else {
                try fileManager.moveItem(at: tempFileURL, to: destinationURL)
            }

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
}
