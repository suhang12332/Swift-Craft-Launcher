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

    // 对于mod，需要检查hash是否已安装
    guard resourceTypeLowercased == "mod" else {
        // 对于其他资源类型，暂时不检查是否已安装，返回所有兼容的游戏
        return compatibleGames
    }

    // 第二步和第三步：使用兼容的游戏列表的版本信息和资源信息查询该资源的版本信息，判断每个版本的hash是否安装
    return await withTaskGroup(of: GameVersionInfo?.self) { group in
        for game in compatibleGames {
            group.addTask {
                // 使用兼容的游戏列表的版本信息和资源信息查询该资源的版本信息
                guard let versions = try? await ModrinthService.fetchProjectVersionsFilter(
                    id: projectId,
                    selectedVersions: [game.gameVersion],
                    selectedLoaders: [game.modLoader],
                    type: resourceType
                ), let firstVersion = versions.first else {
                    // 如果无法获取版本信息，返回该游戏（认为未安装）
                    return game
                }

                // 获取主文件的hash
                guard let primaryFile = ModrinthService.filterPrimaryFiles(from: firstVersion.files) else {
                    // 如果没有主文件，返回该游戏（认为未安装）
                    return game
                }

                // 判断该版本的hash是否安装
                let modsDir = AppPaths.modsDirectory(gameName: game.gameName)
                let resourceHash = primaryFile.hashes.sha1
                if ModScanner.shared.isModInstalledSync(hash: resourceHash, in: modsDir) {
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
