import Foundation

// MARK: - 兼容游戏过滤（按照完整流程：过滤兼容 -> 查询版本信息 -> 检查hash是否安装）
func filterCompatibleGames(
    detail: ModrinthProjectDetail,
    gameRepository: GameRepository,
    resourceType: String,
    projectId: String
) async -> [GameVersionInfo] {
    let supportedVersions = Set(detail.gameVersions)
    let supportedLoaders = Set(detail.loaders.map { $0.lowercased() })
    let resourceTypeLowercased = resourceType.lowercased()

    // 第一步：根据资源兼容版本和本地游戏列表过滤，过滤出兼容的游戏版本
    let compatibleGames = gameRepository.games.compactMap { game -> GameVersionInfo? in
        let localLoader = game.modLoader.lowercased()
        let match: Bool = {
            switch (resourceTypeLowercased, localLoader) {
            case (ResourceType.datapack.rawValue, "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(ResourceType.datapack.rawValue)
            case (ResourceType.shader.rawValue, let loader) where loader != "vanilla":
                return supportedVersions.contains(game.gameVersion)
            case (ResourceType.resourcepack.rawValue, "vanilla"):
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains("minecraft")
            case (ResourceType.resourcepack.rawValue, _),
                 (ResourceType.minecraftJavaServer.rawValue, _):
                return supportedVersions.contains(game.gameVersion)
            default:
                return supportedVersions.contains(game.gameVersion)
                    && supportedLoaders.contains(localLoader)
            }
        }()
        return match ? game : nil
    }

    // 第二步和第三步：使用兼容的游戏列表的版本信息和资源信息查询该资源的版本信息，
    // 判断该资源在对应游戏下是否已安装（基于所有兼容版本的哈希）
    return await withTaskGroup(of: GameVersionInfo?.self) { group in
        for game in compatibleGames {
            group.addTask {
                // 获取当前资源类型在该游戏下的安装目录（mods/datapacks/resourcepacks/shaderpacks）
                let resourceDir =
                    AppPaths.resourceDirectory(for: resourceType, gameName: game.gameName)
                    ?? AppPaths.modsDirectory(gameName: game.gameName)

                // 判断该资源在该游戏下是否已安装（使用统一的哈希检测逻辑）
                let isInstalled = await ModrinthService.isProjectInstalledByAnyCompatibleVersion(
                    projectId: projectId,
                    selectedVersions: [game.gameVersion],
                    selectedLoaders: [game.modLoader],
                    type: resourceType,
                    modsDir: resourceDir
                )

                if isInstalled {
                    // 已安装，不返回
                    return nil
                }

                // 未安装，返回该游戏
                return game
            }
        }

        var results: [GameVersionInfo] = []
        for await game in group {
            if let game = game {
                results.append(game)
            }
        }
        return results
    }
}
