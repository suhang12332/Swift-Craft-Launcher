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
    return gameRepository.games.compactMap { game in
        let localLoader = game.modLoader.lowercased()
        let match: Bool = {
            switch (resourceType, localLoader) {
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
        guard match else { return nil }
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
