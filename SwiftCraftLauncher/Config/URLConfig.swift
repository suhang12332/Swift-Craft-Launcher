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

        // GitHub API
        enum GitHub {
            static let baseURL = URLConfig.url("https://api.github.com")
            static let repositoryOwner = "suhang12332"
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
                version: String? = nil,
                architecture: String
            ) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                if let version = version, !version.isEmpty {
                    return URLConfig.url("https://github.com/\(repositoryOwner)/\(repositoryName)/releases/download/\(version)/\(appcastFileName)")
                } else {
                    return URLConfig.url("https://github.com/\(repositoryOwner)/\(repositoryName)/releases/latest/download/\(appcastFileName)")
                }
            }
        }

        // Modrinth API
        enum Modrinth {
            static var baseURL: URL {
                guard let url = URL(string: GameSettingsManager.shared.modrinthAPIBaseURL) else {
                    fatalError("Invalid Modrinth API base URL: \(GameSettingsManager.shared.modrinthAPIBaseURL)")
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
    }
}
