import Foundation

enum URLConfig {
    // 安全创建 URL 的辅助方法
    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            fatalError("Invalid URL: \(string)")
        }
        return url
    }

    // 常量字符串，避免重复创建
    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

    // 公共方法：为 GitHub URL 应用代理（如果需要）
    /// 为 GitHub 相关的 URL 应用 gitProxyURL 代理
    /// - Parameter url: 原始 URL
    /// - Returns: 应用代理后的 URL（如果需要）
    static func applyGitProxyIfNeeded(_ url: URL) -> URL {
        let proxy = "https://ghfast.top"
        guard !proxy.isEmpty else { return url }

        // 优化：直接使用 URL 的 host 属性，避免转换为 String
        guard let host = url.host else { return url }

        // 仅对 GitHub 相关域名应用代理（排除 api.github.com）
        let isGitHubURL = host == githubHost || host == rawGithubHost
        guard isGitHubURL else { return url }

        // 优化：使用 URL 的 absoluteString 检查是否已有代理前缀
        let urlString = url.absoluteString
        if urlString.hasPrefix("\(proxy)/") { return url }

        // 使用字符串插值而非字符串拼接
        let proxiedString = proxy.hasSuffix("/") ? "\(proxy)\(urlString)" : "\(proxy)/\(urlString)"
        return Self.url(proxiedString)
    }

    // 公共方法：为 GitHub URL 字符串应用代理（如果需要）
    /// 为 GitHub 相关的 URL 字符串应用 gitProxyURL 代理
    /// - Parameter urlString: 原始 URL 字符串
    /// - Returns: 应用代理后的 URL 字符串（如果需要）
    /// 优化：使用 autoreleasepool 及时释放临时 URL 对象
    static func applyGitProxyIfNeeded(_ urlString: String) -> String {
        return autoreleasepool {
            guard let url = URL(string: urlString) else { return urlString }
            return applyGitProxyIfNeeded(url).absoluteString
        }
    }

    // API 端点
    enum API {
        // Authentication API
        enum Authentication {
            // Microsoft OAuth - Authorization Code Flow
            static let authorize = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize")
            static let token = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            static let redirectUri = "swift-craft-launcher://auth"

            // Xbox Live
            static let xboxLiveAuth = URLConfig.url("https://user.auth.xboxlive.com/user/authenticate")
            static let xstsAuth = URLConfig.url("https://xsts.auth.xboxlive.com/xsts/authorize")

            // Minecraft Services
            static let minecraftLogin = URLConfig.url("https://api.minecraftservices.com/authentication/login_with_xbox")
            static let minecraftProfile = URLConfig.url("https://api.minecraftservices.com/minecraft/profile")
            static let minecraftEntitlements = URLConfig.url("https://api.minecraftservices.com/entitlements/mcstore")
            // Player skin / cape operations
            static let minecraftProfileSkins = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins")
            static let minecraftProfileActiveSkin = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins/active")
            static let minecraftProfileActiveCape = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/capes/active")
        }

        // Minecraft API
        enum Minecraft {
            static let versionList = URLConfig.url("https://launchermeta.mojang.com/mc/game/version_manifest.json")
        }

        // Java Runtime API
        enum JavaRuntime {
            static let baseURL = URLConfig.url("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871")
            static let allRuntimes = baseURL.appendingPathComponent("all.json")

            /// 获取Java运行时清单
            /// - Parameter manifestURL: 清单URL
            /// - Returns: 清单URL
            static func manifest(_ manifestURL: String) -> URL {
                return URLConfig.url(manifestURL)
            }
        }

        // ARM平台专用版本的Zulu JDK下载URL
        enum JavaRuntimeARM {
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_aarch64.zip")
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_aarch64.zip")
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_aarch64.zip")
        }

        // Intel平台专用版本的Zulu JDK下载URL
        enum JavaRuntimeIntel {
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_x64.zip")
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_x64.zip")
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_x64.zip")
        }

        // GitHub API
        enum GitHub {
            static let baseURL = URLConfig.url("https://api.github.com")
            static let repositoryOwner = "suhang12332"
            static let assetsRepositoryName = "Swift-Craft-Launcher-Assets"
            static let repositoryName = "Swift-Craft-Launcher"
            /// 公告基础地址：
            /// 例如：https://raw.githubusercontent.com/suhang12332/Swift-Craft-Launcher-Assets/refs/heads/main/news/api/announcements/0.3.1-beta/ar.json
            static let announcementBaseURL = URLConfig.url("https://raw.githubusercontent.com/\(repositoryOwner)/\(assetsRepositoryName)/refs/heads/main/news/api/announcements")

            // 私有方法：构建仓库基础路径
            private static var repositoryBaseURL: URL {
                baseURL
                    .appendingPathComponent("repos")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            static func latestRelease() -> URL {
                URLConfig.applyGitProxyIfNeeded(
                    repositoryBaseURL.appendingPathComponent("releases/latest")
                )
            }

            static func contributors(perPage: Int = 50) -> URL {
                let url = repositoryBaseURL
                    .appendingPathComponent("contributors")
                    .appending(queryItems: [
                        URLQueryItem(name: "per_page", value: "\(perPage)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // Appcast 相关
            static func appcastURL(
                architecture: String
            ) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                let url = URLConfig.url("https://github.com")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("releases")
                    .appendingPathComponent("latest")
                    .appendingPathComponent("download")
                    .appendingPathComponent(appcastFileName)
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // 静态贡献者数据
            static func staticContributors() -> URL {
                let timestamp = Int(Date().timeIntervalSince1970)
                let url = URLConfig.url("https://raw.githubusercontent.com")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(assetsRepositoryName)
                    .appendingPathComponent("refs")
                    .appendingPathComponent("heads")
                    .appendingPathComponent("main")
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("contributors.json")
                    .appending(queryItems: [
                        URLQueryItem(name: "timestamp", value: "\(timestamp)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // 致谢数据
            static func acknowledgements() -> URL {
                let timestamp = Int(Date().timeIntervalSince1970)
                let url = URLConfig.url("https://raw.githubusercontent.com")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(assetsRepositoryName)
                    .appendingPathComponent("refs")
                    .appendingPathComponent("heads")
                    .appendingPathComponent("main")
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("acknowledgements.json")
                    .appending(queryItems: [
                        URLQueryItem(name: "timestamp", value: "\(timestamp)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // LICENSE 文件
            static func license(ref: String = "main") -> URL {
                let url = repositoryBaseURL
                    .appendingPathComponent("contents")
                    .appendingPathComponent("LICENSE")
                    .appending(queryItems: [
                        URLQueryItem(name: "ref", value: ref)
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // Announcement API
            /// 获取公告URL
            /// - Parameters:
            ///   - version: 应用版本号
            ///   - language: 语言代码，如 "zh-Hans"
            /// - Returns: 公告URL（带时间戳，避免缓存）
            static func announcement(version: String, language: String) -> URL {
                let timestamp = Int(Date().timeIntervalSince1970)
                let url = announcementBaseURL
                    .appendingPathComponent(version)
                    .appendingPathComponent("\(language).json")
                    .appending(queryItems: [
                        URLQueryItem(name: "timestamp", value: "\(timestamp)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }
        }

        // Modrinth API
        enum Modrinth {
            static let baseURL = URLConfig.url("https://api.modrinth.com/v2")

            // 项目相关
            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            // 版本相关
            static func version(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)/version")
            }

            static func versionId(versionId: String) -> URL {
                baseURL.appendingPathComponent("version/\(versionId)")
            }

            // 搜索相关
            static var search: URL {
                baseURL.appendingPathComponent("search")
            }

            static func versionFile(hash: String) -> URL {
                baseURL.appendingPathComponent("version_file/\(hash)")
            }

            // 标签相关
            static var gameVersionTag: URL {
                baseURL.appendingPathComponent("tag/game_version")
            }

            static var loaderTag: URL {
                baseURL.appendingPathComponent("tag/loader")
            }

            static var categoryTag: URL {
                baseURL.appendingPathComponent("tag/category")
            }

            // Loader API
            static func loaderManifest(loader: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/manifest.json")
            }

            // Minecraft Version API
            static func versionInfo(version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/minecraft/v0/versions/\(version).json")
            }

            static let maven = URLConfig.url("https://launcher-meta.modrinth.com/maven/")

            static func loaderProfile(loader: String, version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/versions/\(version).json")
            }

            // 下载 URL
            /// 生成 Modrinth 文件下载 URL
            /// - Parameters:
            ///   - projectId: 项目 ID
            ///   - versionId: 版本 ID
            ///   - fileName: 文件名（会自动进行 URL 编码）
            /// - Returns: 下载 URL
            static func downloadUrl(projectId: String, versionId: String, fileName: String) -> String {
                let encodedFileName = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
                return "https://cdn.modrinth.com/data/\(projectId)/versions/\(versionId)/\(encodedFileName)"
            }
        }
        // FabricMC API
        enum Fabric {
            static let loader = URLConfig.url("https://meta.fabricmc.net/v2/versions/loader")
        }

        // Quilt API
        enum Quilt {
            static let loaderBase = URLConfig.url("https://meta.quiltmc.org/v3/versions/loader/")
        }

        // CurseForge API
        enum CurseForge {
            static let mirrorBaseURL = URLConfig.url("https://api.curseforge.com/v1")
            static let fallbackDownloadBaseURL = URLConfig.url("https://edge.forgecdn.net/files")

            static func fileDetail(projectId: Int, fileId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files/\(fileId)")
            }

            static func modDetail(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)")
            }

            static func fallbackDownloadUrl(fileId: Int, fileName: String) -> URL {
                // 格式：https://edge.forgecdn.net/files/{fileId前三位}/{fileId后三位}/{fileName}
                fallbackDownloadBaseURL
                    .appendingPathComponent("\(fileId / 1000)")
                    .appendingPathComponent("\(fileId % 1000)")
                    .appendingPathComponent(fileName)
            }

            static func projectFiles(projectId: Int, gameVersion: String? = nil, modLoaderType: Int? = nil) -> URL {
                let url = mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files")

                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                var queryItems: [URLQueryItem] = []

                if let gameVersion = gameVersion {
                    queryItems.append(URLQueryItem(name: "gameVersion", value: gameVersion))
                }

                if let modLoaderType = modLoaderType {
                    queryItems.append(URLQueryItem(name: "modLoaderType", value: String(modLoaderType)))
                }

                if !queryItems.isEmpty {
                    components?.queryItems = queryItems
                }

                return components?.url ?? url
            }

            // 搜索相关
            static var search: URL {
                mirrorBaseURL.appendingPathComponent("mods/search")
            }

            // 分类相关
            static var categories: URL {
                mirrorBaseURL.appendingPathComponent("categories")
            }

            // 游戏版本相关
            static var gameVersions: URL {
                mirrorBaseURL.appendingPathComponent("minecraft/version")
            }
        }
    }
}
