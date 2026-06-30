//
//  URLConfig.swift
//  Config
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A collection of URL constants and builders used throughout the launcher.
///
/// `URLConfig` provides a centralized registry of network endpoints, API paths,
/// and resource locations. Nested types group related URLs by service domain
/// (authentication, mod platforms, GitHub, community, and so on).
enum URLConfig {
    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(string: "https://localhost") ?? URL(fileURLWithPath: "/")
    }

    private enum GitHubProxySettings {
        static var defaultProxy: String { Defaults.gitProxyURL }

        static var isEnabled: Bool {
            let defaults = UserDefaults.standard
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

    /// Returns a proxied version of the given URL when a GitHub proxy is configured and enabled.
    ///
    /// Only URLs targeting `github.com` or `raw.githubusercontent.com` are proxied.
    /// If the URL is already proxied, it is returned unchanged.
    ///
    /// - Parameter url: The original URL.
    /// - Returns: A proxied URL if applicable; otherwise the original URL.
    static func applyGitProxyIfNeeded(_ url: URL) -> URL {
        guard let host = url.host else { return url }
        let isGitHubURL = host == githubHost || host == rawGithubHost
        guard isGitHubURL else { return url }

        guard GitHubProxySettings.isEnabled else { return url }
        guard let proxy = GitHubProxySettings.normalizedProxyPrefix else { return url }

        let urlString = url.absoluteString
        if urlString.hasPrefix("\(proxy)/") { return url }

        let proxiedString = "\(proxy)/\(urlString)"
        return Self.url(proxiedString)
    }

    /// Returns a proxied version of the given URL string when a GitHub proxy is configured and enabled.
    ///
    /// - Parameter urlString: The original URL string.
    /// - Returns: A proxied URL string if applicable; otherwise the original string.
    static func applyGitProxyIfNeeded(_ urlString: String) -> String {
        return autoreleasepool {
            guard let url = URL(string: urlString) else { return urlString }
            return applyGitProxyIfNeeded(url).absoluteString
        }
    }

    enum API {
        enum Authentication {
            /// The Microsoft OAuth authorization endpoint.
            static let authorize = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize")
            /// The Microsoft OAuth token endpoint.
            static let token = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            /// The OAuth redirect URI registered for this application.
            static let redirectUri = "com.su.code.swiftcraftlauncher://oauth"
            /// The Xbox Live authentication endpoint.
            static let xboxLiveAuth = URLConfig.url("https://user.auth.xboxlive.com/user/authenticate")
            /// The Xbox XSTS authorization endpoint.
            static let xstsAuth = URLConfig.url("https://xsts.auth.xboxlive.com/xsts/authorize")
            /// The Xbox Live SiteName value used in authentication requests.
            static let xboxLiveSiteName = "user.auth.xboxlive.com"
            /// The Xbox Live RelyingParty identifier.
            static let xboxLiveRelyingParty = "http://auth.xboxlive.com"

            /// The Minecraft Services login endpoint.
            static let minecraftLogin = URLConfig.url("https://api.minecraftservices.com/authentication/login_with_xbox")
            /// The Minecraft profile endpoint.
            static let minecraftProfile = URLConfig.url("https://api.minecraftservices.com/minecraft/profile")
            /// The Minecraft entitlements verification endpoint.
            static let minecraftEntitlements = URLConfig.url("https://api.minecraftservices.com/entitlements/mcstore")
            /// The Minecraft Services RelyingParty identifier.
            static let minecraftRelyingParty = "rp://api.minecraftservices.com/"
            /// The Minecraft profile skins endpoint.
            static let minecraftProfileSkins = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins")
            /// The Minecraft profile active skin endpoint.
            static let minecraftProfileActiveSkin = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins/active")
            /// The Minecraft profile active cape endpoint.
            static let minecraftProfileActiveCape = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/capes/active")
        }

        enum MinecraftNews {
            /// Returns the news article URL for a Java Edition release version.
            ///
            /// - Parameter version: A release version string (e.g. "1.26.1").
            /// - Returns: The full article URL.
            static func javaEditionRelease(version: String) -> URL {
                let slug = CommonUtil.minecraftReleaseNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }

            /// Returns the news article URL for a snapshot version.
            ///
            /// - Parameter version: A snapshot version string (e.g. "26w11a").
            /// - Returns: The full article URL.
            static func snapshot(version: String) -> URL {
                let slug = CommonUtil.minecraftSnapshotNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }
        }

        enum JavaRuntime {
            /// The base URL for the Mojang Java Runtime manifest.
            static let baseURL = URLConfig.url("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871")
            /// The URL for the complete Java Runtime manifest listing all available runtimes.
            static let allRuntimes = baseURL.appendingPathComponent("all.json")
        }

        enum JavaRuntimeARM {
            /// The Zulu JRE Legacy (Java 8) download URL for Apple Silicon.
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_aarch64.zip")
            /// The Zulu Java Runtime Alpha (Java 16) download URL for Apple Silicon.
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_aarch64.zip")
            /// The Zulu Java Runtime Beta (Java 17) download URL for Apple Silicon.
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_aarch64.zip")
        }

        enum JavaRuntimeIntel {
            /// The Zulu JRE Legacy (Java 8) download URL for Intel.
            static let jreLegacy = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu8.88.0.19-ca-jre8.0.462-macosx_x64.zip")
            /// The Zulu Java Runtime Alpha (Java 16) download URL for Intel.
            static let javaRuntimeAlpha = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu16.32.15-ca-jre16.0.2-macosx_x64.zip")
            /// The Zulu Java Runtime Beta (Java 17) download URL for Intel.
            static let javaRuntimeBeta = URLConfig.url("https://cdn.azul.com/zulu/bin/zulu17.60.17-ca-jre17.0.16-macosx_x64.zip")
        }

        enum AuthlibInjector {
            /// The download URL for the current version of Authlib Injector.
            static let download = URLConfig.applyGitProxyIfNeeded(
                URLConfig.url("https://github.com/yushijinhun/authlib-injector/releases/download/v\(AppConstants.AuthlibInjector.version)/\(AppConstants.AuthlibInjector.jarFileName)")
            )

            /// Returns the normalized API root address expected by Authlib Injector.
            ///
            /// Strips trailing slashes and whitespace from the given base URL.
            ///
            /// - Parameter baseURL: The Yggdrasil server base URL.
            /// - Returns: A normalized API root string (e.g. "https://littleskin.cn").
            static func serverApiRoot(for baseURL: String) -> String {
                var normalizedBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                while normalizedBaseURL.hasSuffix("/") {
                    normalizedBaseURL.removeLast()
                }
                return normalizedBaseURL
            }
        }

        enum Yggdrasil {
            /// The LittleSkin Yggdrasil server base URL.
            static let littleSkinBaseURL = URLConfig.url("https://littleskin.cn")
            /// The MUA skin server base URL.
            static let muaBaseURL = URLConfig.url("https://skin.mualliance.ltd")
            /// The Ely.by Yggdrasil server base URL.
            static let elyBaseURL = URLConfig.url("https://account.ely.by")
        }

        enum GitHub {
            /// The GitHub web base URL.
            static let baseURL = URLConfig.url("https://github.com")
            /// The GitHub REST API base URL.
            static let apiBaseURL = URLConfig.url("https://api.github.com")
            /// The GitHub Pages base URL for launcher assets.
            static let assetBaseURL = URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets")

            static let repositoryOwner = "suhang12332"
            static let repositoryName = "Swift-Craft-Launcher"

            private static var announcementBaseURL: URL {
                assetBaseURL
                    .appendingPathComponent("news")
                    .appendingPathComponent("api")
                    .appendingPathComponent("announcements")
            }

            private static var repositoryApiBaseURL: URL {
                apiBaseURL
                    .appendingPathComponent("repos")
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            /// Returns the API URL for listing repository contributors.
            ///
            /// - Parameter perPage: The number of contributors per page. Defaults to 50.
            /// - Returns: The contributors API URL, routed through the proxy if enabled.
            static func contributors(perPage: Int = 50) -> URL {
                let url = repositoryApiBaseURL
                    .appendingPathComponent("contributors")
                    .appending(queryItems: [
                        URLQueryItem(name: "per_page", value: "\(perPage)")
                    ])
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// Returns the web URL for the project repository.
            static func repositoryURL() -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            /// Returns the release page URL for the specified version tag.
            ///
            /// - Parameter version: The release version tag.
            /// - Returns: The release page URL.
            static func releaseTag(version: String) -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("releases")
                    .appendingPathComponent("tag")
                    .appendingPathComponent(version)
            }

            /// Returns the Sparkle appcast feed URL for the given architecture.
            ///
            /// - Parameter architecture: The target architecture identifier (e.g. "arm64", "x86_64").
            /// - Returns: The appcast XML download URL, routed through the proxy if enabled.
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

            /// Returns the URL for the static contributors JSON file.
            static func staticContributors() -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("contributors.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// Returns the URL for the acknowledgements JSON file.
            static func acknowledgements() -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("contributors")
                    .appendingPathComponent("acknowledgements.json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// Returns the URL for a game icon asset.
            ///
            /// - Parameter value: The game identifier used as the icon filename.
            /// - Returns: The icon image URL, routed through the proxy if enabled.
            static func gameIcon(_ value: String) -> URL {
                let url = assetBaseURL
                    .appendingPathComponent("imagebed")
                    .appendingPathComponent("gameicons")
                    .appendingPathComponent("\(value).png")
                return URLConfig.applyGitProxyIfNeeded(url)
            }

            /// Returns the URL for the LICENSE file on GitHub.
            ///
            /// This endpoint bypasses the GitHub proxy.
            ///
            /// - Parameter ref: The git reference. Defaults to `"main"`.
            /// - Returns: The LICENSE file URL.
            static func license(ref: String = "main") -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
                    .appendingPathComponent("blob")
                    .appendingPathComponent(ref)
                    .appendingPathComponent("LICENSE")
            }

            /// Returns the announcement URL for the specified version and language.
            ///
            /// - Parameters:
            ///   - version: The application version string.
            ///   - language: A language code (e.g. "zh-Hans", "en").
            /// - Returns: The announcement JSON URL, routed through the proxy if enabled.
            static func announcement(version: String, language: String) -> URL {
                let url = announcementBaseURL
                    .appendingPathComponent(version)
                    .appendingPathComponent("\(language).json")
                return URLConfig.applyGitProxyIfNeeded(url)
            }
        }

        enum Community {
            /// Returns the project website URL.
            static func website() -> URL {
                URLConfig.url("https://suhang12332.github.io/Swift-Craft-Launcher-Assets/web/")
            }

            /// Returns the GitHub Discussions URL.
            static func discussions() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/discussions")
            }

            /// Returns the GitHub Issues URL for bug reports.
            static func issues() -> URL {
                URLConfig.url("https://github.com/suhang12332/Swift-Craft-Launcher/issues")
            }

            /// Returns the Discord invite URL.
            static func discord() -> URL {
                URLConfig.url("https://discord.gg/gYESVa3CZd")
            }

            /// Returns the QQ group invite URL.
            static func qq() -> URL {
                URLConfig.url("https://qm.qq.com/cgi-bin/qm/qr?k=1057517524")
            }

            /// Returns the AI documentation URL.
            static func aiDocumentation() -> URL {
                URLConfig.url("https://zread.ai/suhang12332/Swift-Craft-Launcher")
            }
        }

        enum Modrinth {
            /// The Modrinth API v2 base URL.
            static let baseURL = URLConfig.url("https://api.modrinth.com/v2")
            /// The Modrinth API v3 base URL.
            static let baseURLV3 = URLConfig.url("https://api.modrinth.com/v3")
            /// The Modrinth web project base URL for building project links.
            static let webProjectBase = "https://modrinth.com/mod/"

            /// Returns the v2 API URL for the specified project.
            ///
            /// - Parameter id: The Modrinth project identifier.
            /// - Returns: The project detail URL.
            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            /// Returns the v3 API URL for the specified project, including server-related fields.
            ///
            /// - Parameter id: The Modrinth project identifier.
            /// - Returns: The project detail URL.
            static func projectV3(id: String) -> URL {
                baseURLV3.appendingPathComponent("project/\(id)")
            }

            /// Returns the URL for listing versions of a project.
            ///
            /// - Parameter id: The Modrinth project identifier.
            /// - Returns: The version list URL.
            static func version(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)/version")
            }

            /// Returns the URL for a specific version.
            ///
            /// - Parameter versionId: The Modrinth version identifier.
            /// - Returns: The version detail URL.
            static func versionId(versionId: String) -> URL {
                baseURL.appendingPathComponent("version/\(versionId)")
            }

            /// The Modrinth search endpoint.
            static var search: URL {
                baseURL.appendingPathComponent("search")
            }

            /// Returns the URL for looking up a version by file hash.
            ///
            /// - Parameter hash: The file hash value.
            /// - Returns: The version lookup URL.
            static func versionFile(hash: String) -> URL {
                baseURL.appendingPathComponent("version_file/\(hash)")
            }

            /// The game version tag endpoint.
            static var gameVersionTag: URL {
                baseURL.appendingPathComponent("tag/game_version")
            }

            /// The mod loader tag endpoint.
            static var loaderTag: URL {
                baseURL.appendingPathComponent("tag/loader")
            }

            /// The category tag endpoint.
            static var categoryTag: URL {
                baseURL.appendingPathComponent("tag/category")
            }

            /// Returns the loader metadata manifest URL.
            ///
            /// - Parameter loader: The mod loader name (e.g. "fabric", "forge").
            /// - Returns: The manifest JSON URL.
            static func loaderManifest(loader: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/manifest.json")
            }

            /// Returns the Minecraft version metadata URL.
            ///
            /// - Parameter version: The Minecraft version string.
            /// - Returns: The version metadata JSON URL.
            static func versionInfo(version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/minecraft/v0/versions/\(version).json")
            }

            /// Returns the loader profile URL for a specific loader and Minecraft version.
            ///
            /// - Parameters:
            ///   - loader: The mod loader name (e.g. "fabric", "forge").
            ///   - version: The Minecraft version string.
            /// - Returns: The loader profile JSON URL.
            static func loaderProfile(loader: String, version: String) -> URL {
                return URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/versions/\(version).json")
            }
        }

        enum ChunkBase {
            /// The ChunkBase seed map base URL.
            static let seedMapBase = "https://www.chunkbase.com/apps/seed-map"

            /// Returns the ChunkBase seed map URL for the given world seed.
            ///
            /// - Parameter seed: The world seed value.
            /// - Returns: The seed map URL, or `nil` if the URL cannot be constructed.
            static func seedMap(seed: Int64) -> URL? {
                URL(string: "\(seedMapBase)#seed=\(seed)")
            }
        }

        enum Fabric {
            /// The Fabric meta API URL for loader versions.
            static let loader = URLConfig.url("https://meta.fabricmc.net/v2/versions/loader")
        }

        enum Quilt {
            /// The Quilt meta API base URL for loader versions.
            static let loaderBase = URLConfig.url("https://meta.quiltmc.org/v3/versions/loader/")
        }

        enum CurseForge {
            /// The CurseForge API v1 base URL.
            static let mirrorBaseURL = URLConfig.url("https://api.curseforge.com/v1")
            /// The CurseForge CDN fallback base URL for file downloads.
            static let fallbackDownloadBaseURL = URLConfig.url("https://edge.forgecdn.net/files")
            /// The CurseForge web project base URL for building project links.
            static let webProjectBase = "https://www.curseforge.com/minecraft/"

            /// Returns the CurseForge web project list URL for the specified resource type.
            ///
            /// - Parameter projectType: The resource type (e.g. "mod", "resourcepack", "datapack", "shader", "modpack").
            /// - Returns: The project list base URL string.
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

            /// Returns the CurseForge API URL for a specific file.
            ///
            /// - Parameters:
            ///   - projectId: The CurseForge project identifier.
            ///   - fileId: The CurseForge file identifier.
            /// - Returns: The file detail URL.
            static func fileDetail(projectId: Int, fileId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files/\(fileId)")
            }

            /// Returns the CurseForge API URL for a mod's details.
            ///
            /// - Parameter modId: The CurseForge mod identifier.
            /// - Returns: The mod detail URL.
            static func modDetail(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)")
            }

            /// Returns the CurseForge API URL for a mod's description.
            ///
            /// - Parameter modId: The CurseForge mod identifier.
            /// - Returns: The mod description URL.
            static func modDescription(modId: Int) -> URL {
                mirrorBaseURL.appendingPathComponent("mods/\(modId)/description")
            }

            /// Returns a fallback download URL from the CurseForge CDN.
            ///
            /// - Parameters:
            ///   - fileId: The CurseForge file identifier.
            ///   - fileName: The filename to append.
            /// - Returns: The fallback download URL.
            static func fallbackDownloadUrl(fileId: Int, fileName: String) -> URL {
                fallbackDownloadBaseURL
                    .appendingPathComponent("\(fileId / 1000)")
                    .appendingPathComponent("\(fileId % 1000)")
                    .appendingPathComponent(fileName)
            }

            /// Returns the CurseForge API URL for a project's file list.
            ///
            /// - Parameters:
            ///   - projectId: The CurseForge project identifier.
            ///   - gameVersion: An optional Minecraft version to filter by.
            ///   - modLoaderType: An optional mod loader type to filter by.
            /// - Returns: The file list URL with the specified query parameters.
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

            /// The CurseForge mods search endpoint.
            static var search: URL {
                mirrorBaseURL.appendingPathComponent("mods/search")
            }

            /// The CurseForge categories endpoint.
            static var categories: URL {
                mirrorBaseURL.appendingPathComponent("categories")
            }

            /// The CurseForge game versions endpoint.
            static var gameVersions: URL {
                mirrorBaseURL.appendingPathComponent("minecraft/version")
            }

            /// The CurseForge file fingerprint matching endpoint.
            static var fingerprints: URL {
                mirrorBaseURL.appendingPathComponent("fingerprints/432")
            }
        }

        enum MinecraftResources {
            /// The Minecraft content delivery base URL.
            static let baseURL = "https://resources.download.minecraft.net"

            /// Returns the download URL for a Minecraft asset.
            ///
            /// - Parameters:
            ///   - hashPrefix: The first two characters of the asset hash.
            ///   - hash: The full asset hash.
            /// - Returns: The asset download URL.
            static func asset(hashPrefix: String, hash: String) -> URL {
                URLConfig.url("\(baseURL)/\(hashPrefix)/\(hash)")
            }
        }

        enum AIService {
            /// The OpenAI API base URL.
            static let openAIBaseURL = "https://api.openai.com"
            /// The default Ollama local server base URL.
            static let ollamaDefaultBaseURL = "http://localhost:11434"
            /// The default avatar URL for AI assistant responses.
            static let defaultAvatarURL = "https://mcskins.top/assets/snippets/download/skin.php?n=7050"
        }

        enum IPLocation {
            /// The IP geolocation lookup endpoint.
            static var currentLocation: URL {
                URLConfig.url("https://ipapi.co/json/")
            }
        }

        enum Ely {
            /// The Ely.by skin system base URL.
            static let baseURL = URLConfig.url("https://skinsystem.ely.by")

            /// Returns the skin texture URL for the specified player.
            ///
            /// - Parameter nickname: The player's Ely.by nickname.
            /// - Returns: The skin texture URL.
            static func textures(nickname: String) -> URL {
                baseURL
                    .appendingPathComponent("textures")
                    .appendingPathComponent(nickname)
            }
        }
    }

    enum Store {
        /// The Minecraft purchase page URL on the Xbox store.
        static let minecraftPurchase = URLConfig.url("https://www.xbox.com/zh-CN/games/store/productId/9NXP44L49SHJ")
    }

    enum Defaults {
        /// The default GitHub proxy base URL.
        static let gitProxyURL = "https://gh-proxy.com"
    }
}
