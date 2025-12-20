import Foundation

// MARK: - 兼容游戏过滤
func filterCompatibleGames(
    detail: ModrinthProjectDetail,
    gameRepository: GameRepository,
    resourceType: String,
    projectId: String
) -> [GameVersionInfo] {
    let supportedVersions = Set(detail.gameVersions)
    let supportedLoaders = Set(detail.loaders.map { $0.lowercased() })
    let resourceTypeLowercased = resourceType.lowercased()

    // 先过滤兼容的游戏（不检查已安装状态）
    let compatibleGames = gameRepository.games.compactMap { game -> GameVersionInfo? in
        let localLoader = game.modLoader.lowercased()
        let match: Bool = {
            switch (resourceTypeLowercased, localLoader) {
            case ("datapack", "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("datapack")
            case ("shader", let loader) where loader != "vanilla":
                return supportedVersions.contains(game.gameVersion)
            case ("resourcepack", "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("minecraft")
            case ("resourcepack", _):
                return supportedVersions.contains(game.gameVersion)
            default:
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(localLoader)
            }
        }()
        return match ? game : nil
    }

    // 只在 resourceType 是 "mod" 时才检查是否已安装（避免不必要的目录扫描）
    guard resourceTypeLowercased == "mod" else {
        return compatibleGames
    }

    // 对于 mod，过滤掉已安装的
    return compatibleGames.compactMap { game in
        let modsDir = AppPaths.modsDirectory(gameName: game.gameName)
        if ModScanner.shared.isModInstalledSync(
            projectId: projectId,
            in: modsDir
        ) {
            return nil
        }
        return game
    }
}
