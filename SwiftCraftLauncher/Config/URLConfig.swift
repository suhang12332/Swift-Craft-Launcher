import Foundation

enum URLConfig {
    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(string: "https://localhost") ?? URL(fileURLWithPath: "/")
    }

    private enum GitHubProxySettings {
        static var defaultProxy: String { Defaults.gitProxyURL }

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

        static var normalizedProxyPrefix: String? {
            let proxy = proxyString
            guard !proxy.isEmpty else { return nil }
            guard let url = URL(string: proxy), let scheme = url.scheme else { return nil }
            guard scheme == "http" || scheme == "https" else { return nil }
            return proxy.hasSuffix("/") ? String(proxy.dropLast()) : proxy
        }
    }

    private static let githubHost = "github.com"
    private static let rawGithubHost = "raw.githubusercontent.com"

    /// 为 GitHub 相关的 URL 应用 gitProxyURL 代理
    /// - Parameter url: 原始 URL
    /// - Returns: 应用代理后的 URL（如果需要）
    static func applyGitProxyIfNeeded(_ url: URL) -> URL {
        guard let host = url.host else { return url }
        // 仅对 GitHub 相关域名应用代理（排除 api.github.com,suhang12332.github.io）
        let isGitHubURL = host == githubHost || host == rawGithubHost
        guard isGitHubURL else { return url }

        guard GitHubProxySettings.isEnabled else { return url }
        guard let proxy = GitHubProxySettings.normalizedProxyPrefix else { return url }

        let urlString = url.absoluteString
        if urlString.hasPrefix("\(proxy)/") { return url }

        let proxiedString = "\(proxy)/\(urlString)"
        return Self.url(proxiedString)
    }

    /// 为 GitHub 相关的 URL 字符串应用 gitProxyURL 代理
    /// - Parameter urlString: 原始 URL 字符串
    /// - Returns: 应用代理后的 URL 字符串（如果需要）
    static func applyGitProxyIfNeeded(_ urlString: String) -> String {
        return autoreleasepool {
            guard let url = URL(string: urlString) else { return urlString }
            return applyGitProxyIfNeeded(url).absoluteString
        }
    }

    // MARK: - API 端点

    enum API {
        /// Microsoft / Xbox / Minecraft 认证相关
        enum Authentication {
            /// Microsoft OAuth - Authorization Code Flow
            static let authorize = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize")
            /// Microsoft OAuth Token
            static let token = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            /// OAuth 回调 URI
            static let redirectUri = "com.su.code.swiftcraftlauncher://oauth"
            /// Xbox Live 认证
            static let xboxLiveAuth = URLConfig.url("https://user.auth.xboxlive.com/user/authenticate")
            /// XSTS 授权
            static let xstsAuth = URLConfig.url("https://xsts.auth.xboxlive.com/xsts/authorize")
            /// Xbox Live SiteName
            static let xboxLiveSiteName = "user.auth.xboxlive.com"
            /// Xbox Live RelyingParty
            static let xboxLiveRelyingParty = "http://auth.xboxlive.com"

            /// Minecraft Services 登录
            static let minecraftLogin = URLConfig.url("https://api.minecraftservices.com/authentication/login_with_xbox")
            /// Minecraft 个人资料
            static let minecraftProfile = URLConfig.url("https://api.minecraftservices.com/minecraft/profile")
            /// Minecraft 权益验证
            static let minecraftEntitlements = URLConfig.url("https://api.minecraftservices.com/entitlements/mcstore")
            /// Minecraft RelyingParty
            static let minecraftRelyingParty = "rp://api.minecraftservices.com/"
            /// Minecraft 皮肤列表
            static let minecraftProfileSkins = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins")
            /// Minecraft 当前皮肤
            static let minecraftProfileActiveSkin = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins/active")
            /// Minecraft 当前披风
            static let minecraftProfileActiveCape = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/capes/active")
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

        /// Java Runtime API
        enum JavaRuntime {
            /// Java Runtime 基础 URL
            static let baseURL = URLConfig.url("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871")
            /// 所有运行时信息
            static let allRuntimes = baseURL.appendingPathComponent("all.json")
        }

        /// ARM 平台专用 Zulu JDK 下载 URL
        enum JavaRuntimeARM {
            /// JRE Legacy (Java 8)
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_aarch64.zip")
            /// Java Runtime Alpha (Java 16)
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_aarch64.zip")
            /// Java Runtime Beta (Java 17)
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_aarch64.zip")
        }

        /// Intel 平台专用 Zulu JDK 下载 URL
        enum JavaRuntimeIntel {
            /// JRE Legacy (Java 8)
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_x64.zip")
            /// Java Runtime Alpha (Java 16)
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_x64.zip")
            /// Java Runtime Beta (Java 17)
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_x64.zip")
        }

        /// Authlib Injector 下载与工具
        enum AuthlibInjector {
            /// Authlib Injector 下载地址
            static let download = URLConfig.applyGitProxyIfNeeded(
                URLConfig.url("https://github.com/yushijinhun/authlib-injector/releases/download/v\(AppConstants.AuthlibInjector.version)/\(AppConstants.AuthlibInjector.jarFileName)")
            )

            /// 根据 Yggdrasil 服务器 baseURL 生成 Authlib Injector 期望的 API 根地址
            /// - Parameter baseURL: 服务器基础 URL
            /// - Returns: 规范化后的 API 根地址，例如 "https://littleskin.cn"
            static func serverApiRoot(for baseURL: String) -> String {
                var normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                while normalizedBaseURL.hasSuffix("/") {
                    normalizedBaseURL.removeLast()
                }
                return normalizedBaseURL
            }
        }

        /// Yggdrasil 服务器（第三方皮肤站）
        enum Yggdrasil {
            /// LittleSkin
            static let littleSkinBaseURL = URLConfig.url("https://littleskin.cn")
            /// MUA 皮肤站
            static let muaBaseURL = URLConfig.url("https://skin.mualliance.ltd")
            /// Ely.by
            static let elyBaseURL = URLConfig.url("https://account.ely.by")
        }

        /// GitHub API
        enum GitHub {
            /// GitHub 主页
            static let baseURL = URLConfig.url("https://github.com")
            /// GitHub API
            static let apiBaseURL = URLConfig.url("https://api.github.com")
            /// GitHub Pages 资源
            static let assetBaseURL = URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets")

            static let repositoryOwner = "suhang12332"
            static let repositoryName = "Swift-Craft-Launcher"

            /// 公告基础地址
            private static var announcementBaseURL: URL {
                assetBaseURL
                    .appendingPathComponent("news")
                    .appendingPathComponent("api")
                    .appendingPathComponent("announcements")
            }

            /// 仓库 API 基础路径
            private static var repositoryApiBaseURL: URL {
                apiBaseURL
                    .appendingPathComponent("repos")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            /// 获取贡献者列表
            static func contributors(perPage: Int = 50) -> URL {
                let url = repositoryApiBaseURL
                    .appendingPathComponent("contributors")
                    .appending(queryItems: [
                        URLQueryItem(name: "per_page", value: "\(perPage)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// GitHub 仓库主页
            static func repositoryURL() -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            /// 指定版本的 Release 页面（tag）
            static func releaseTag(version: String) -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("releases")
                    .appendingPathComponent("tag")
                    .appendingPathComponent(version)
            }

            /// Appcast 更新文件
            static func appcastURL(architecture: String) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                let url = baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("releases")
                    .appendingPathComponent("latest")
                    .appendingPathComponent("download")
                    .appendingPathComponent(appcastFileName)
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// 静态贡献者数据
            static func staticContributors() -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("contributors.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// 致谢数据
            static func acknowledgements() -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("acknowledgements.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// 游戏图标
            static func gameIcon(_ value: String) -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("imagebed")
                    .appendingPathComponent("gameicons")
                    .appendingPathComponent("\(value).png")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// LICENSE 文件（不走 GitHub 代理）
            static func license(ref: String = "main") -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("blob")
                    .appendingPathComponent(ref)
                    .appendingPathComponent("LICENSE")
            }

            /// 获取公告 URL
            /// - Parameters:
            ///   - version: 应用版本号
            ///   - language: 语言代码，如 "zh-Hans"
            /// - Returns: 公告 URL（带时间戳，避免缓存）
            static func announcement(version: String, language: String) -> URL {
                let url = announcementBaseURL
                    .appendingPathComponent(version)
                    .appendingPathComponent("\(language).json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }
        }

        /// 社区链接
        enum Community {
            /// 官网
            static func website() -> URL {
                URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets/web/")
            }

            /// 讨论区
            static func discussions() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/discussions")
            }

            /// 问题反馈
            static func issues() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/issues")
            }

            /// Discord
            static func discord() -> URL {
                URLConfig.url("https://discord.gg/gYESVa3CZd")
            }

            /// QQ 群
            static func qq() -> URL {
                URLConfig.url("https://qm.qq.com/cgi-bin/qm/qr?k=1057517524")
            }

            /// AI 文档
            static func aiDocumentation() -> URL {
                URLConfig.url("https://zread.ai/suhang12332/Swift-Craft-Launcher")
            }
        }

        /// Modrinth API
        enum Modrinth {
            /// Modrinth API v2
            static let baseURL = URLConfig.url("https://api.modrinth.com/v2")
            /// Modrinth API v3
            static let baseURLV3 = URLConfig.url("https://api.modrinth.com/v3")
            /// Modrinth 项目详情基础 URL，例如：https://modrinth.com/mod/fabric-api
            static let webProjectBase = "https://modrinth.com/mod/"

            /// 获取项目详情
            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            /// 获取项目详情（v3，包含服务器信息等新字段）
            static func projectV3(id: String) -> URL {
                baseURLV3.appendingPathComponent("project/\(id)")
            }

            /// 获取项目版本列表
            static func version(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)/version")
            }

            /// 获取版本详情
            static func versionId(versionId: String) -> URL {
                baseURL.appendingPathComponent("version/\(versionId)")
            }

            /// 搜索项目
            static var search: URL {
                baseURL.appendingPathComponent("search")
            }

            /// 根据文件哈希获取版本
            static func versionFile(hash: String) -> URL {
                baseURL.appendingPathComponent("version_file/\(hash)")
            }

            /// 游戏版本标签
            static var gameVersionTag: URL {
                baseURL.appendingPathComponent("tag/game_version")
            }

            /// Loader 标签
            static var loaderTag: URL {
                baseURL.appendingPathComponent("tag/loader")
            }

            /// 分类标签
            static var categoryTag: URL {
                baseURL.appendingPathComponent("tag/category")
            }

            /// Loader Manifest
            static func loaderManifest(loader: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/manifest.json")
            }

            /// Minecraft 版本信息
            static func versionInfo(version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/minecraft/v0/versions/\(version).json")
            }

            /// Loader 配置文件
            static func loaderProfile(loader: String, version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/versions/\(version).json")
            }
        }

        /// ChunkBase 种子地图
        enum ChunkBase {
            /// 种子地图基础 URL
            static let seedMapBase = "https://www.chunkbase.com/apps/seed-map"

            /// 根据世界种子生成 ChunkBase 种子地图 URL
            static func seedMap(seed: Int64) -> URL? {
                URL(string: "\(seedMapBase)#seed=\(seed)")
            }
        }

        /// FabricMC API
        enum Fabric {
            /// Fabric Loader 版本列表
            static let loader = URLConfig.url("https://meta.fabricmc.net/v2/versions/loader")
        }

        /// Quilt API
        enum Quilt {
            /// Quilt Loader 版本列表
            static let loaderBase = URLConfig.url("https://meta.quiltmc.org/v3/versions/loader/")
        }

        /// CurseForge API
        enum CurseForge {
            /// CurseForge API 基础 URL
            static let mirrorBaseURL = URLConfig.url("https://api.curseforge.com/v1")
            /// CurseForge 备用下载地址
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

            /// 获取文件详情
            static func fileDetail(projectId: Int, fileId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files/\(fileId)")
            }

            /// 获取模组详情
            static func modDetail(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)")
            }

            /// 获取模组描述
            static func modDescription(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)/description")
            }

            /// 备用下载地址（edge.forgecdn.net）
            static func fallbackDownloadUrl(fileId: Int, fileName: String) -> URL {
                fallbackDownloadBaseURL
                    .appendingPathComponent("\(fileId / 1000)")
                    .appendingPathComponent("\(fileId % 1000)")
                    .appendingPathComponent(fileName)
            }

            /// 获取项目文件列表
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

            /// 搜索模组
            static var search: URL {
                mirrorBaseURL.appendingPathComponent("mods/search")
            }

            /// 获取分类列表
            static var categories: URL {
                mirrorBaseURL.appendingPathComponent("categories")
            }

            /// 获取游戏版本列表
            static var gameVersions: URL {
                mirrorBaseURL.appendingPathComponent("minecraft/version")
            }

            /// 按文件指纹匹配文件/模组
            static var fingerprints: URL {
                mirrorBaseURL.appendingPathComponent("fingerprints/432")
            }
        }

        /// Minecraft 资源文件下载
        enum MinecraftResources {
            /// 资源文件下载基础 URL
            static let baseURL = "https://resources.download.minecraft.net"

            /// 获取资源文件下载 URL
            static func asset(hashPrefix: String, hash: String) -> URL {
                URLConfig.url("\(baseURL)/\(hashPrefix)/\(hash)")
            }
        }

        /// AI 服务相关
        enum AIService {
            /// OpenAI API 基础 URL
            static let openAIBaseURL = "https://api.openai.com"
            /// Ollama 默认本地地址
            static let ollamaDefaultBaseURL = "http://localhost:11434"
            /// AI 头像默认 URL
            static let defaultAvatarURL = "https://mcskins.top/assets/snippets/download/skin.php?n=7050"
        }

        /// IP 地理位置 API
        enum IPLocation {
            /// 获取当前 IP 位置信息
            static var currentLocation: URL {
                URLConfig.url("https://ipapi.co/json/")
            }
        }

        /// Ely.by Skin System API
        enum Ely {
            /// Ely.by 皮肤系统基础 URL
            static let baseURL = URLConfig.url("https://skinsystem.ely.by")

            /// 获取玩家皮肤纹理
            static func textures(nickname: String) -> URL {
                baseURL
                    .appendingPathComponent("textures")
                    .appendingPathComponent(nickname)
            }
        }
    }

    // MARK: - Store URLs

    enum Store {
        /// Minecraft 购买链接
        static let minecraftPurchase = URLConfig.url("https://www.xbox.com/zh-CN/games/store/productId/9NXP44L49SHJ")
    }

    // MARK: - 默认值

    enum Defaults {
        /// GitHub 代理默认地址
        static let gitProxyURL = "https://gh-proxy.com"
    }
}
