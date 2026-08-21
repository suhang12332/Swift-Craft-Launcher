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

    enum API {
        enum Authentication {
            static let authorize = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize")
            static let token = URLConfig.url("https://login.microsoftonline.com/consumers/oauth2/v2.0/token")
            /// The OAuth redirect URI registered for this application.
            static let redirectUri = "com.su.code.swiftcraftlauncher://oauth"
            static let xboxLiveAuth = URLConfig.url("https://user.auth.xboxlive.com/user/authenticate")
            static let xstsAuth = URLConfig.url("https://xsts.auth.xboxlive.com/xsts/authorize")
            static let xboxLiveSiteName = "user.auth.xboxlive.com"
            static let xboxLiveRelyingParty = "http://auth.xboxlive.com"

            static let minecraftLogin = URLConfig.url("https://api.minecraftservices.com/authentication/login_with_xbox")
            static let minecraftProfile = URLConfig.url("https://api.minecraftservices.com/minecraft/profile")
            static let minecraftEntitlements = URLConfig.url("https://api.minecraftservices.com/entitlements/mcstore")
            static let minecraftLicense = URLConfig.url("https://api.minecraftservices.com/entitlements/license")
            static let minecraftRelyingParty = "rp://api.minecraftservices.com/"
            static let minecraftProfileSkins = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins")
            static let minecraftProfileActiveSkin = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/skins/active")
            static let minecraftProfileActiveCape = URLConfig.url("https://api.minecraftservices.com/minecraft/profile/capes/active")
        }

        enum MinecraftNews {
            static func javaEditionRelease(version: String) -> URL {
                let slug = CommonUtil.minecraftReleaseNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }

            static func snapshot(version: String) -> URL {
                let slug = CommonUtil.minecraftSnapshotNewsSlug(version: version)
                return URLConfig.url("https://www.minecraft.net/en-us/article/\(slug)")
            }
        }

        enum JavaRuntime {
            /// The URL for the complete Java Runtime manifest listing all available runtimes.
            static let allRuntimes = URLConfig.url("https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json")
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
            /// The GitHub API URL for fetching the latest Authlib Injector release.
            static let latestRelease = URLConfig.url("https://api.github.com/repos/yushijinhun/authlib-injector/releases/latest")

            static func jarFileName(_ version: String) -> String {
                "authlib-injector-\(version).jar"
            }

            static func downloadURL(_ version: String) -> URL {
                URLConfig.url("https://github.com/yushijinhun/authlib-injector/releases/download/v\(version)/\(jarFileName(version))")
            }

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
            static let littleSkinBaseURL = URLConfig.url("https://littleskin.cn")
            static let muaBaseURL = URLConfig.url("https://skin.mualliance.ltd")
            static let elyBaseURL = URLConfig.url("https://account.ely.by")
        }

        enum GitHub {
            /// The GitHub web base URL.
            static let baseURL = URLConfig.url("https://github.com")

            static let repositoryOwner = "suhang12332"
            static let repositoryName = "Swift-Craft-Launcher"

            static func repositoryURL() -> URL {
                baseURL
                    .appendingPathComponent(repositoryOwner)
                    .appendingPathComponent(repositoryName)
            }

            static func contributors() -> URL {
                URLConfig.url("https://swift-craft-launcher-contributors.suhang12332.workers.dev/contributors")
            }

            static func releaseTag(version: String) -> URL {
                repositoryURL()
                    .appendingPathComponent("releases")
                    .appendingPathComponent("tag")
                    .appendingPathComponent(version)
            }

            static func staticContributors() -> URL {
                URLConfig.url("https://swift-craft-launcher-contributors.pages.dev")
                    .appendingPathComponent("contributors.json")
            }

            static func acknowledgements() -> URL {
                URLConfig.url("https://swift-craft-launcher-contributors.pages.dev")
                    .appendingPathComponent("acknowledgements.json")
            }

            static func gameIcon(_ value: String) -> URL {
                URLConfig.url("https://swift-craft-launcher-imagebed.pages.dev")
                    .appendingPathComponent("gameicons")
                    .appendingPathComponent("\(value).png")
            }

            static func license(ref: String = "main") -> URL {
                repositoryURL()
                    .appendingPathComponent("blob")
                    .appendingPathComponent(ref)
                    .appendingPathComponent("LICENSE")
            }

            static func announcement(version: String, language: String) -> URL {
                URLConfig.url("https://swift-craft-launcher-news.pages.dev")
                    .appendingPathComponent(version)
                    .appendingPathComponent("\(language).json")
            }
        }

        enum Sparkle {
            /// The base URL for application update downloads.
            static let downloadBaseURL = URLConfig.url("https://swift-craft-launcher-download.suhang12332.workers.dev")

            /// Returns the Sparkle appcast feed URL for the given architecture.
            ///
            /// - Parameter architecture: The target architecture identifier (e.g. "arm64", "x86_64").
            /// - Returns: The appcast XML download URL.
            static func appcastURL(architecture: String) -> URL {
                let appcastFileName = "appcast-\(architecture).xml"
                return URLConfig.url("https://swift-craft-launcher-update.suhang12332.workers.dev")
                    .appendingPathComponent(appcastFileName)
            }
        }

        enum Community {
            static func website() -> URL {
                URLConfig.url("https://swift-craft-launcher-web.pages.dev")
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

            static func aiDocumentation() -> URL {
                URLConfig.url("https://zread.ai/suhang12332/Swift-Craft-Launcher")
            }
        }

        enum Modrinth {
            static let baseURL = URLConfig.url("https://api.modrinth.com/v2")
            static let baseURLV3 = URLConfig.url("https://api.modrinth.com/v3")
            static let webProjectBase = "https://modrinth.com/mod/"

            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            static func projectV3(id: String) -> URL {
                baseURLV3.appendingPathComponent("project/\(id)")
            }

            static func version(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)/version")
            }

            static func versionId(versionId: String) -> URL {
                baseURL.appendingPathComponent("version/\(versionId)")
            }

            static var search: URL {
                baseURL.appendingPathComponent("search")
            }

            static func versionFile(hash: String) -> URL {
                baseURL.appendingPathComponent("version_file/\(hash)")
            }

            static var gameVersionTag: URL {
                baseURL.appendingPathComponent("tag/game_version")
            }

            static var loaderTag: URL {
                baseURL.appendingPathComponent("tag/loader")
            }

            static var categoryTag: URL {
                baseURL.appendingPathComponent("tag/category")
            }

            static func loaderManifest(loader: String) -> URL {
                URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/manifest.json")
            }

            static func versionInfo(version: String) -> URL {
                URLConfig.url("https://launcher-meta.modrinth.com/minecraft/v0/versions/\(version).json")
            }

            static func loaderProfile(loader: String, version: String) -> URL {
                URLConfig.url("https://launcher-meta.modrinth.com/\(loader)/v0/versions/\(version).json")
            }
        }

        enum ChunkBase {
            static let seedMapBase = "https://www.chunkbase.com/apps/seed-map"

            static func seedMap(seed: Int64) -> URL? {
                URL(string: "\(seedMapBase)#seed=\(seed)")
            }
        }

        enum Fabric {
            static let loader = URLConfig.url("https://meta.fabricmc.net/v2/versions/loader")
        }

        enum Quilt {
            static let loaderBase = URLConfig.url("https://meta.quiltmc.org/v3/versions/loader/")
        }

        enum CurseForge {
            static let mirrorBaseURL = URLConfig.url("https://api.curseforge.com/v1")
            static let fallbackDownloadBaseURL = URLConfig.url("https://edge.forgecdn.net/files")
            static let webProjectBase = "https://www.curseforge.com/minecraft/"

            static func webProjectURL(projectType: String) -> String {
                let type = projectType.lowercased()
                let pathPrefix = switch type {
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
                fallbackDownloadBaseURL
                    .appendingPathComponent("\(fileId / 1000)")
                    .appendingPathComponent("\(fileId % 1000)")
                    .appendingPathComponent(fileName)
            }

            static func projectFiles(projectId: Int, gameVersion: String? = nil, modLoaderType: Int? = nil) -> URL {
                let url = mirrorBaseURL.appendingPathComponent("mods/\(projectId)/files")

                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                var queryItems: [URLQueryItem] = []

                if let gameVersion {
                    queryItems.append(URLQueryItem(name: "gameVersion", value: gameVersion))
                }

                if let modLoaderType {
                    queryItems.append(URLQueryItem(name: "modLoaderType", value: String(modLoaderType)))
                }

                if !queryItems.isEmpty {
                    components?.queryItems = queryItems
                }

                return components?.url ?? url
            }

            static var search: URL {
                mirrorBaseURL.appendingPathComponent("mods/search")
            }

            static var categories: URL {
                mirrorBaseURL.appendingPathComponent("categories")
            }

            static var gameVersions: URL {
                mirrorBaseURL.appendingPathComponent("minecraft/version")
            }

            static var fingerprints: URL {
                mirrorBaseURL.appendingPathComponent("fingerprints/432")
            }
        }

        enum MinecraftResources {
            static let baseURL = "https://resources.download.minecraft.net"

            static func asset(hashPrefix: String, hash: String) -> URL {
                URLConfig.url("\(baseURL)/\(hashPrefix)/\(hash)")
            }
        }

        enum DefaultAvatars: String, CaseIterable {
            case alex, ari, efe, kai, makena, noor, steve, sunny, zuri

            private static let baseURL = URLConfig.url("https://swift-craft-launcher-imagebed.pages.dev/skins")
            var url: URL {
                Self.baseURL.appendingPathComponent("\(rawValue).png")
            }

            static var all: [URL] {
                allCases.map(\.url)
            }
        }

        enum AIService {
            static let openAIBaseURL = "https://api.openai.com"
            static let ollamaDefaultBaseURL = "http://localhost:11434"
            static let defaultAvatarURL = "https://mcskins.top/assets/snippets/download/skin.php?n=7050"

            static let openAIChatPath = "/v1/chat/completions"
            static let ollamaChatPath = "/api/chat"
        }

        enum IPLocation {
            static var currentLocation: URL {
                URLConfig.url("https://ipapi.co/json/")
            }
        }

        enum Ely {
            static let baseURL = URLConfig.url("https://skinsystem.ely.by")

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

        /// The Minecraft page for creating a Java Edition game profile.
        static let minecraftProfileCreation = URLConfig.url("https://www.minecraft.net/msaprofile/mygames/editprofile")
    }
}
