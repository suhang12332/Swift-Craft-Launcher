import Foundation

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
                let lowercasedPath = url.lastPathComponent.lowercased()
                if lowercasedPath.hasSuffix(".\(AppConstants.FileExtensions.jar)") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.datapacksDirectory(gameName: game.gameName)
            case .shader:
                return AppPaths.shaderpacksDirectory(gameName: game.gameName)
            case .resourcepack:
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
        return try await downloadFile(
            urlString: url.absoluteString,
            destinationURL: destURL,
            expectedSha1: expectedSha1
        )
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
        do {
            return try await ProgressDownloadManager.downloadFile(
                urlString: urlString,
                destinationURL: destinationURL,
                expectedSha1: expectedSha1,
                progressHandler: nil
            )
        } catch {
            throw mapDownloadError(error)
        }
    }

    private static func mapDownloadError(_ error: Error) -> Error {
        if error is CancellationError {
            return error
        }
        if let globalError = error as? GlobalError {
            return globalError
        }
        if error is URLError {
            return GlobalError.download(
                chineseMessage: "网络请求失败",
                i18nKey: "error.download.network_request_failed",
                level: .notification
            )
        }
        return GlobalError.download(
            chineseMessage: "下载失败",
            i18nKey: "error.download.general_failure",
            level: .notification
        )
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
