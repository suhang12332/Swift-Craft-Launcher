import Foundation

enum URLConfig {
    // 安全创建 URL 的辅助方法
    private static func url(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            fatalError("Invalid URL: \(string)")
        }
        return url
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

        // GitHub API
        enum GitHub {
            static let baseURL = URLConfig.url("https://api.github.com")
            static let repositoryOwner = "suhang12332"
            static let assetsRepositoryName = "Swift-Craft-Launcher-Assets"
            static let repositoryName = "Swift-Craft-Launcher"

            // 私有方法：构建仓库基础路径
            private static var repositoryBaseURL: URL {
                baseURL
                    .appendingPathComponent("repos")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            static func latestRelease() -> URL {
                repositoryBaseURL.appendingPathComponent("releases/latest")
            }

            static func contributors(perPage: Int = 50) -> URL {
                repositoryBaseURL
                    .appendingPathComponent("contributors")
                    .appending(queryItems: [
                        URLQueryItem(name: "per_page", value: "\(perPage)")
                    ])
            }

            // Appcast 相关
            static func appcastURL(
                architecture: String
            ) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                return URLConfig.url("https://github.com/\(repositoryOwner)/\(repositoryName)/releases/latest/download/\(appcastFileName)")
            }

            // 静态贡献者数据
            static func staticContributors() -> URL {
                let timestamp = Int(Date().timeIntervalSince1970)
                let urlString = "https://raw.githubusercontent.com/\(repositoryOwner)/\(assetsRepositoryName)/refs/heads/main/contributors/contributors.json?timestamp=\(timestamp)"
                return URLConfig.url(urlString)
            }

            // 致谢数据
            static func acknowledgements() -> URL {
                let timestamp = Int(Date().timeIntervalSince1970)
                let urlString = "https://raw.githubusercontent.com/\(repositoryOwner)/\(assetsRepositoryName)/refs/heads/main/contributors/acknowledgements.json?timestamp=\(timestamp)"
                return URLConfig.url(urlString)
            }
        }

        // Modrinth API
        enum Modrinth {
            static var baseURL: URL {
                guard let url = URL(string: GeneralSettingsManager.shared.modrinthAPIBaseURL) else {
                    fatalError("Invalid Modrinth API base URL: \(GeneralSettingsManager.shared.modrinthAPIBaseURL)")
                }
                return url
            }

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
        }
        // FabricMC API
        enum Fabric {
            static let loader = URLConfig.url("https://meta.fabricmc.net/v2/versions/loader")
        }

        // Forge API
        enum Forge {
            static let gitReleasesBase = URLConfig.url("https://github.com/\(URLConfig.API.GitHub.repositoryOwner)/forge-client/releases/download/")
        }

        // NeoForge API
        enum NeoForge {
            static let gitReleasesBase = URLConfig.url("https://github.com/\(URLConfig.API.GitHub.repositoryOwner)/neoforge-client/releases/download/")
        }

        // Quilt API
        enum Quilt {
            static let loaderBase = URLConfig.url("https://meta.quiltmc.org/v3/versions/loader/")
        }

        // CurseForge API
        enum CurseForge {
            static let mirrorBaseURL = URLConfig.url("https://mod.mcimirror.top/curseforge/v1")
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
        }

        // Announcement API
        enum Announcement {
            static let baseURL = "https://suhang12332.github.io/Swift-Craft-Launcher-News/api/announcements"

            /// 获取公告URL
            /// - Parameters:
            ///   - version: 应用版本号
            ///   - language: 语言代码，如 "zh-Hans"
            /// - Returns: 公告URL
            static func announcement(version: String, language: String) -> URL {
                let urlString = "\(baseURL)/\(version)/\(language).json"
                return URLConfig.url(urlString)
            }
        }
    }
}
