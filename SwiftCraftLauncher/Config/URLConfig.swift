import Foundation

enum URLConfig {
    /// 安全创建 URL 的辅助方法，无效时记录日志并返回占位 URL，避免生产环境闪退
    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(string: "https://localhost") ?? URL(fileURLWithPath: "/")
    }

    /// GitHub 代理设置（从 UserDefaults 读取，避免 UI 依赖）
    private enum GitHubProxySettings {
        static let defaultProxy = "https://gh-proxy.com"

        static var isEnabled: Bool {
            let defaults = UserDefaults.standard
            // 未写入时默认开启
            return (defaults.object(forKey: AppConstants.UserDefaultsKeys.enableGitHubProxy) as? Bool) ?? true
        }

        static var proxyString: String {
            let defaults = UserDefaults.standard
            return (defaults.string(forKey: AppConstants.UserDefaultsKeys.gitProxyURL) ?? defaultProxy)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// 返回用于拼接的代理前缀（保证为 http(s) 且不以 / 结尾），无效则返回 nil
        static var normalizedProxyPrefix: String? {
            let proxy = proxyString
            guard !proxy.isEmpty else { return nil }
            guard let url = URL(string: proxy), let scheme = url.scheme else { return nil }
            guard scheme == "http" || scheme == "https" else { return nil }
            return proxy.hasSuffix("/") ? String(proxy.dropLast()) : proxy
        }
    }

    // 常量字符串，避免重复创建
    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

    // 公共方法：为 GitHub URL 应用代理（如果需要）
    /// 为 GitHub 相关的 URL 应用 gitProxyURL 代理
    /// - Parameter url: 原始 URL
    /// - Returns: 应用代理后的 URL（如果需要）
    static func applyGitProxyIfNeeded(_ url: URL) -> URL {
        // 优化：直接使用 URL 的 host 属性，避免转换为 String
        guard let host = url.host else { return url }
        // 仅对 GitHub 相关域名应用代理（排除 api.github.com,suhang12332.github.io）
        let isGitHubURL = host == githubHost || host == rawGithubHost
        guard isGitHubURL else { return url }

        guard GitHubProxySettings.isEnabled else { return url }
        guard let proxy = GitHubProxySettings.normalizedProxyPrefix else { return url }

        // 优化：使用 URL 的 absoluteString 检查是否已有代理前缀
        let urlString = url.absoluteString
        if urlString.hasPrefix("\(proxy)/") { return url }

        // 使用字符串插值而非字符串拼接
        let proxiedString = "\(proxy)/\(urlString)"
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
            static let xboxLiveSiteName = "user.auth.xboxlive.com"
            static let xboxLiveRelyingParty = "http://auth.xboxlive.com"

            // Minecraft Services
            static let minecraftLogin = URLConfig.url("https://api.minecraftservices.com/authentication/login_with_xbox")
            static let minecraftProfile = URLConfig.url("https://api.minecraftservices.com/minecraft/profile")
            static let minecraftEntitlements = URLConfig.url("https://api.minecraftservices.com/entitlements/mcstore")
            static let minecraftRelyingParty = "rp://api.minecraftservices.com/"
            // Player skin / cape operations
            static let minecraftProfileSkins = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins")
            static let minecraftProfileActiveSkin = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins/active")
            static let minecraftProfileActiveCape = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/capes/active")
        }

        // Minecraft API
        enum Minecraft {
            static let versionList = URLConfig.url("https://launchermeta.mojang.com/mc/game/version_manifest.json")
        }

        /// Minecraft 新闻文章链接生成
        enum MinecraftNews {
            /// 根据版本号生成正式版文章链接，例如 1.26.1 -> minecraft-java-edition-26-1
            static func javaEditionRelease(version: String) -> URL {
                let slug = CommonUtil.minecraftReleaseNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }

            /// 根据快照版本生成文章链接，例如 26w11a -> minecraft-26-1-snapshot-11
            static func snapshot(version: String) -> URL {
                let slug = CommonUtil.minecraftSnapshotNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }
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

        // 第三方认证相关
        enum AuthlibInjector {
            static let download = URLConfig.applyGitProxyIfNeeded(
                URLConfig.url("https://github.com/yushijinhun/authlib-injector/releases/download/v\(AppConstants.AuthlibInjector.version)/\(AppConstants.AuthlibInjector.jarFileName)")
            )

            /// 根据 Yggdrasil 服务器 baseURL 生成 Authlib Injector 期望的 API 根地址
            /// 例如 baseURL = https://littleskin.cn/ -> https://littleskin.cn
            static func serverApiRoot(for baseURL: String) -> String {
                var normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                while normalizedBaseURL.hasSuffix("/") {
                    normalizedBaseURL.removeLast()
                }
                return normalizedBaseURL
            }
        }

        // Yggdrasil 服务器（第三方皮肤站）
        enum Yggdrasil {
            static let littleSkinBaseURL = URLConfig.url("https://littleskin.cn")
            static let muaBaseURL = URLConfig.url("https://skin.mualliance.ltd")
            static let elyBaseURL = URLConfig.url("https://account.ely.by")
        }

        // GitHub API
        enum GitHub {
            static let gitHubBase = URLConfig.url("https://github.com")
            static let baseURL = URLConfig.url("https://api.github.com")
            static let assetBaseURL = URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets")

            static let repositoryOwner = "suhang12332"
            static let repositoryName = "Swift-Craft-Launcher"
            /// 公告基础地址：
            private static var announcementBaseURL: URL {
                assetBaseURL
                    .appendingPathComponent("news")
                    .appendingPathComponent("api")
                    .appendingPathComponent("announcements")
            }

            // 私有方法：构建仓库基础路径 api
            private static var repositoryApiBaseURL: URL {
                baseURL
                    .appendingPathComponent("repos")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            static func latestRelease() -> URL {
                URLConfig.applyGitProxyIfNeeded(
                    repositoryApiBaseURL.appendingPathComponent("releases/latest")
                )
            }

            static func contributors(perPage: Int = 50) -> URL {
                let url = repositoryApiBaseURL
                    .appendingPathComponent("contributors")
                    .appending(queryItems: [
                        URLQueryItem(name: "per_page", value: "\(perPage)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // GitHub 仓库主页 URL
            static func repositoryURL() -> URL {
                gitHubBase
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            /// 指定版本的 Release 页面（tag）
            static func releaseTag(version: String) -> URL {
                gitHubBase
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("releases")
                    .appendingPathComponent("tag")
                    .appendingPathComponent(version)
            }

            // Appcast 相关
            static func appcastURL(
                architecture: String
            ) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                let url = gitHubBase
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
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("contributors.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // 致谢数据
            static func acknowledgements() -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("acknowledgements.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            static func gameIcon(_ value: String) -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("imagebed")
                    .appendingPathComponent("gameicons")
                    .appendingPathComponent("\(value).png")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            // LICENSE 文件（API）
            static func license(ref: String = "main") -> URL {
                gitHubBase
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("blob")
                    .appendingPathComponent(ref)
                    .appendingPathComponent("LICENSE")
                // License 网页不走 GitHub 代理，直接打开原始 github.com 链接
            }

            // Announcement API
            /// 获取公告URL
            /// - Parameters:
            ///   - version: 应用版本号
            ///   - language: 语言代码，如 "zh-Hans"
            /// - Returns: 公告URL（带时间戳，避免缓存）
            static func announcement(version: String, language: String) -> URL {
                let url = announcementBaseURL
                    .appendingPathComponent(version)
                    .appendingPathComponent("\(language).json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }
        }

        enum Community {
            static func website() -> URL {
                URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets/web/")
            }

            static func discussions() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/discussions")
            }

            static func issues() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/issues")
            }

            static func discord() -> URL {
                URLConfig.url("https://discord.gg/gYESVa3CZd")
            }

            static func qq() -> URL {
                URLConfig.url("https://qm.qq.com/cgi-bin/qm/qr?k=1057517524")
            }
        }

        // Modrinth API
        enum Modrinth {
            static let baseURL = URLConfig.url("https://api.modrinth.com/v2")
            static let baseURLV3 = URLConfig.url("https://api.modrinth.com/v3")
            /// Modrinth 项目详情基础 URL，例如：https://modrinth.com/mod/fabric-api
            static let webProjectBase = "https://modrinth.com/mod/"

            // 项目相关
            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            // 项目相关（v3，包含服务器信息等新字段）
            static func projectV3(id: String) -> URL {
                baseURLV3.appendingPathComponent("project/\(id)")
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

        // ChunkBase 种子地图
        enum ChunkBase {
            static let seedMapBase = "https://www.chunkbase.com/apps/seed-map"
            /// 根据世界种子生成 ChunkBase 种子地图 URL
            static func seedMap(seed: Int64) -> URL? {
                URL(string: "\(seedMapBase)#seed=\(seed)")
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
            /// CurseForge 项目详情基础 URL，例如：https://www.curseforge.com/minecraft/mc-mods/geckolib
            static let webProjectBase = "https://www.curseforge.com/minecraft/"

            /// 根据项目类型获取 CurseForge 项目网页基础 URL
            /// - Parameter projectType: 项目类型，如 "mod"、"resourcepack"、"datapack"、"shader"、"modpack"
            /// - Returns: 对应类型的项目列表基础 URL
            static func webProjectURL(projectType: String) -> String {
                let type = projectType.lowercased()
                let pathPrefix: String = switch type {
                case ResourceType.mod.rawValue:
                    "mc-mods/"
                case ResourceType.resourcepack.rawValue:
                    "texture-packs/"
                case ResourceType.datapack.rawValue:
                    "data-packs/"
                case ResourceType.shader.rawValue:
                    "shaders/"
                case ResourceType.modpack.rawValue:
                    "modpacks/"
                default:
                    "mc-mods/"
                }
                return "\(webProjectBase)\(pathPrefix)"
            }

            static func fileDetail(projectId: Int, fileId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files/\(fileId)")
            }

            static func modDetail(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)")
            }

            static func modDescription(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)/description")
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

            // Fingerprints (按文件指纹匹配文件/模组)
            static var fingerprints: URL {
                mirrorBaseURL.appendingPathComponent("fingerprints/432")
            }
        }

        // IP Location API
        enum IPLocation {
            static var currentLocation: URL {
                // 使用 ipapi.co 的免费API，支持HTTPS，返回国家代码
                URLConfig.url("https://ipapi.co/json/")
            }
        }

        // Ely.by Skin System API
        enum Ely {
            static let skinSystemBase = URLConfig.url("https://skinsystem.ely.by")

            static func textures(nickname: String) -> URL {
                skinSystemBase
                    .appendingPathComponent("textures")
                    .appendingPathComponent(nickname)
            }
        }
    }

    // Store URLs
    enum Store {
        // Minecraft 购买链接
        static let minecraftPurchase = URLConfig.url("https://www.xbox.com/zh-CN/games/store/productId/9NXP44L49SHJ")
    }
}
