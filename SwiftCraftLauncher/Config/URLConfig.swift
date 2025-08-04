import Foundation

enum URLConfig {
    // API 端点
    enum API {
        // Authentication API
        enum Authentication {
            // Microsoft OAuth
//          static let deviceCode = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/devicecode")!
//          static let token = URL(string: "https://login.microsoftonline.com/consumers/oauth2/v2.0/token")!
//          
//          // Xbox Live
//          static let xboxLiveAuth = URL(string: "https://user.auth.xboxlive.com/user/authenticate")!
//          static let xstsAuth = URL(string: "https://xsts.auth.xboxlive.com/xsts/authorize")!
//          
//          // Minecraft Services
//          static let minecraftLogin = URL(string: "https://api.minecraftservices.com/authentication/login_with_xbox")!
//          static let minecraftProfile = URL(string: "https://api.minecraftservices.com/minecraft/profile")!
            
            static let deviceCode = URL(string: "https://localhost:8081/consumers/oauth2/v2.0/devicecode")!
            static let token = URL(string: "https://localhost:8081/consumers/oauth2/v2.0/token")!
            
            // Xbox Live
            static let xboxLiveAuth = URL(string: "https://localhost:8081/user/authenticate")!
            static let xstsAuth = URL(string: "https://localhost:8081/xsts/authorize")!
            
            // Minecraft Services
            static let minecraftLogin = URL(string: "https://localhost:8081/authentication/login_with_xbox")!
            static let minecraftProfile = URL(string: "https://localhost:8081/minecraft/profile")!
          
        }

        // Minecraft API
        enum Minecraft {
            static let versionList = URL(string: "https://launchermeta.mojang.com/mc/game/version_manifest.json")!
        }

        // Modrinth API
        enum Modrinth {
            static let baseURL = URL(string: GameSettingsManager.shared.modrinthAPIBaseURL)!
            
            // 项目相关
            static func project(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)")
            }

            // 版本相关
            static func version(id: String) -> URL {
                baseURL.appendingPathComponent("project/\(id)/version")
            }
//            https://api.modrinth.com/v2/version/ND4ROcMQ
            static func versionId(versionId: String) -> URL {
                baseURL.appendingPathComponent("version/\(versionId)")
            }
            
            // 搜索相关
            static let search = baseURL.appendingPathComponent("search")

            static func versionFile(hash: String) -> URL {
                baseURL.appendingPathComponent("version_file/\(hash)")
            }

            // 标签相关
            enum Tag {
                // 游戏版本
                static let gameVersion = Modrinth.baseURL.appendingPathComponent("tag/game_version")

                // 加载器
                static let loader = Modrinth.baseURL.appendingPathComponent("tag/loader")

                // 分类
                static let category = Modrinth.baseURL.appendingPathComponent("tag/category")
            }
            
            // Loader API
            static func loaderManifest(loader: String) -> URL {
                URL(string: "https://launcher-meta.modrinth.com/\(loader)/v0/manifest.json")!
            }
            static let maven = URL(string: "https://launcher-meta.modrinth.com/maven/")!
            
            static func loaderProfile(loader: String,version: String) -> URL {
                URL(string: "https://launcher-meta.modrinth.com/\(loader)/v0/versions/\(version).json")!
            }
        }
        // FabricMC API
        enum Fabric {
            static let loader = URL(string: "https://meta.fabricmc.net/v2/versions/loader")!
        }
        
        // Forge API
        enum Forge {
            static let gitReleasesBase = URL(string: "https://github.com/suhang12332/forge-client/releases/download/")!
        }

        // NeoForge API
        enum NeoForge {
            static let gitReleasesBase = URL(string: "https://github.com/suhang12332/neoforge-client/releases/download/")!
        }

        // Quilt API
        enum Quilt {
            static let loaderBase = URL(string: "https://meta.quiltmc.org/v3/versions/loader/")!
        }
    }
}
