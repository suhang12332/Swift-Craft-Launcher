import Foundation
import CommonCrypto

enum DownloadManager {
    enum ResourceType: String {
        case mod, datapack, shader, resourcepack

        var folderName: String {
            switch self {
            case .mod: return "mods"
            case .datapack: return "datapacks"
            case .shader: return "shaderpacks"
            case .resourcepack: return "resourcepacks"
            }
        }

        init?(from string: String) {
            switch string.lowercased() {
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
                chineseMessage: "无效的下载地址: \(urlString)",
                i18nKey: "error.validation.invalid_download_url",
                level: .notification
            )
        }

        guard let type = ResourceType(from: resourceType) else {
            throw GlobalError.resource(
                chineseMessage: "未知的资源类型: \(resourceType)",
                i18nKey: "error.resource.unknown_type",
                level: .notification
            )
        }

        let resourceDir: URL? = {
            switch type {
            case .mod:
                return AppPaths.modsDirectory(gameName: game.gameName)
            case .datapack:
                if url.lastPathComponent.lowercased().hasSuffix(".jar") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.datapacksDirectory(gameName: game.gameName)
            case .shader:
                return AppPaths.shaderpacksDirectory(gameName: game.gameName)
            case .resourcepack:
                if url.lastPathComponent.lowercased().hasSuffix(".jar") {
                    return AppPaths.modsDirectory(gameName: game.gameName)
                }
                return AppPaths.resourcepacksDirectory(gameName: game.gameName)
            }
        }()

        guard let resourceDirUnwrapped = resourceDir else {
            throw GlobalError.resource(
                chineseMessage: "无法获取资源目录: \(type.folderName) for game: \(game.gameName)",
                i18nKey: "error.resource.directory_not_found",
                level: .notification
            )
        }

        let destURL = resourceDirUnwrapped.appendingPathComponent(url.lastPathComponent)
        return try await downloadFile(urlString: urlString, destinationURL: destURL, expectedSha1: expectedSha1)
    }

    /// 通用下载文件到指定路径（不做任何目录结构拼接）
    /// - Parameters:
    ///   - urlString: 下载地址
    ///   - destinationURL: 目标文件路径
    ///   - expectedSha1: 预期 SHA1 值
    /// - Returns: 下载到的本地文件 URL
    /// - Throws: GlobalError 当操作失败时
    static func downloadFile(
        urlString: String,
        destinationURL: URL,
        expectedSha1: String? = nil
    ) async throws -> URL {
        Logger.shared.info("下载文件 \(urlString) -> \(destinationURL.path)")

        var finalURLString = urlString
        if urlString.hasPrefix("https://github.com/") {
            let proxy = GameSettingsManager.shared.gitProxyURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !proxy.isEmpty {
                finalURLString = proxy + "/" + urlString
            }
        }

        guard let url = URL(string: finalURLString) else {
            throw GlobalError.validation(
                chineseMessage: "无效的下载地址: \(urlString)",
                i18nKey: "error.validation.invalid_download_url",
                level: .notification
            )
        }

        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw GlobalError.fileSystem(
                chineseMessage: "创建目标目录失败: \(error.localizedDescription)",
                i18nKey: "error.filesystem.download_directory_creation_failed",
                level: .notification
            )
        }

        // 检查是否需要 SHA1 校验
        let shouldCheckSha1 = (expectedSha1?.isEmpty == false)

        // 如果文件已存在
        if fileManager.fileExists(atPath: destinationURL.path) {
            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                // 有 SHA1 时进行校验
                do {
                    let actualSha1 = try calculateFileSHA1(at: destinationURL)
                    if actualSha1 == expectedSha1 {
                        Logger.shared.info("文件已存在且 SHA1 校验通过，跳过下载: \(destinationURL.path)")
                        return destinationURL
                    }
                } catch {
                    Logger.shared.warning("SHA1 校验失败，将重新下载: \(error.localizedDescription)")
                }
            } else {
                // 没有 SHA1 时直接跳过
                Logger.shared.info("文件已存在且无需 SHA1 校验，跳过下载: \(destinationURL.path)")
                return destinationURL
            }
        }

        // 下载文件到临时位置
        do {
            let (tempFileURL, response) = try await URLSession.shared.download(from: url)
            defer { try? fileManager.removeItem(at: tempFileURL) }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GlobalError.download(
                    chineseMessage: "无效的 HTTP 响应",
                    i18nKey: "error.download.invalid_http_response",
                    level: .notification
                )
            }

            guard httpResponse.statusCode == 200 else {
                throw GlobalError.download(
                    chineseMessage: "HTTP 请求失败，状态码: \(httpResponse.statusCode)",
                    i18nKey: "error.download.http_status_error",
                    level: .notification
                )
            }

            // SHA1 校验
            if shouldCheckSha1, let expectedSha1 = expectedSha1 {
                do {
                    let actualSha1 = try calculateFileSHA1(at: tempFileURL)
                    if actualSha1 != expectedSha1 {
                        throw GlobalError.validation(
                            chineseMessage: "SHA1 校验失败，期望: \(expectedSha1)，实际: \(actualSha1)",
                            i18nKey: "error.validation.sha1_check_failed",
                            level: .notification
                        )
                    }
                } catch {
                    if error is GlobalError {
                        throw error
                    } else {
                        throw GlobalError.validation(
                            chineseMessage: "SHA1 校验失败: \(error.localizedDescription)",
                            i18nKey: "error.validation.sha1_check_error",
                            level: .notification
                        )
                    }
                }
            }

            // 原子性地移动到最终位置
            do {
                // 如果目标文件已存在，先删除它
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempFileURL, to: destinationURL)
            } catch {
                throw GlobalError.fileSystem(
                    chineseMessage: "移动文件失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.download_file_move_failed",
                    level: .notification
                )
            }

            return destinationURL
        } catch {
            // 转换错误为 GlobalError
            if let globalError = error as? GlobalError {
                throw globalError
            } else if let urlError = error as? URLError {
                throw GlobalError.download(
                    chineseMessage: "网络请求失败: \(urlError.localizedDescription)",
                    i18nKey: "error.download.network_request_failed",
                    level: .notification
                )
            } else {
                throw GlobalError.download(
                    chineseMessage: "下载失败: \(error.localizedDescription)",
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
