import Foundation

extension GameCreationViewModel {
    // MARK: - Version Management

    /// 初始化版本选择器
    func initializeVersionPicker() async {
        let includeSnapshots = GameSettingsManager.shared.includeSnapshotsForGameVersions
        let compatibleVersions = await CommonService.compatibleVersions(
            for: selectedModLoader,
            includeSnapshots: includeSnapshots
        )
        await updateAvailableVersions(compatibleVersions)
    }

    /// 更新可用版本并设置默认选择
    func updateAvailableVersions(_ versions: [String]) async {
        self.availableVersions = versions
        // 如果当前选中的版本不在兼容版本列表中，选择第一个兼容版本
        if !versions.contains(self.selectedGameVersion) && !versions.isEmpty {
            self.selectedGameVersion = versions.first ?? ""
        }

        // 获取当前选中版本的时间信息
        if !versions.isEmpty {
            let targetVersion = versions.contains(self.selectedGameVersion) ? self.selectedGameVersion : (versions.first ?? "")
            let timeString = await ModrinthService.queryVersionTime(from: targetVersion)
            self.versionTime = timeString
            updateDefaultGameName()
        }
    }

    /// 处理模组加载器变化
    func handleModLoaderChange(_ newLoader: String) {
        Task {
            let includeSnapshots = GameSettingsManager.shared.includeSnapshotsForGameVersions
            let compatibleVersions = await CommonService.compatibleVersions(
                for: newLoader,
                includeSnapshots: includeSnapshots
            )
            await updateAvailableVersions(compatibleVersions)

            // 更新加载器版本列表
            if newLoader != GameLoader.vanilla.displayName && !selectedGameVersion.isEmpty {
                await updateLoaderVersions(for: newLoader, gameVersion: selectedGameVersion)
            } else {
                await MainActor.run {
                    availableLoaderVersions = []
                    selectedLoaderVersion = ""
                    updateDefaultGameName()
                }
            }
        }
    }

    /// 处理游戏版本变化
    func handleGameVersionChange(_ newGameVersion: String) {
        Task {
            await updateLoaderVersions(for: selectedModLoader, gameVersion: newGameVersion)
        }
    }

    /// 更新加载器版本列表
    func updateLoaderVersions(for loader: String, gameVersion: String) async {
        guard loader != GameLoader.vanilla.displayName && !gameVersion.isEmpty else {
            availableLoaderVersions = []
            selectedLoaderVersion = ""
            updateDefaultGameName()
            return
        }

        var versions: [String] = []

        switch loader.lowercased() {
        case GameLoader.fabric.displayName:
            let fabricVersions = await FabricLoaderService.fetchAllLoaderVersions(for: gameVersion)
            versions = fabricVersions.map { $0.loader.version }
        case GameLoader.forge.displayName:
            do {
                let forgeVersions = try await ForgeLoaderService.fetchAllForgeVersions(for: gameVersion)
                versions = forgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 Forge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case GameLoader.neoforge.displayName:
            do {
                let neoforgeVersions = try await NeoForgeLoaderService.fetchAllNeoForgeVersions(for: gameVersion)
                versions = neoforgeVersions.loaders.map { $0.id }
            } catch {
                Logger.shared.error("获取 NeoForge 版本失败: \(error.localizedDescription)")
                versions = []
            }
        case GameLoader.quilt.rawValue:
            let quiltVersions = await QuiltLoaderService.fetchAllQuiltLoaders(for: gameVersion)
            versions = quiltVersions.map { $0.loader.version }
        default:
            versions = []
        }

        availableLoaderVersions = versions
        // 如果当前选中的版本不在列表中，选择第一个版本
        if !versions.contains(selectedLoaderVersion) && !versions.isEmpty {
            selectedLoaderVersion = versions.first ?? ""
        } else if versions.isEmpty {
            selectedLoaderVersion = ""
        }
        updateDefaultGameName()
    }

    /// 根据当前选择的版本和加载器自动生成默认游戏名称
    /// 加载器、游戏版本或加载器版本任意一个变化时，都重新生成
    func updateDefaultGameName() {
        guard !selectedGameVersion.isEmpty else { return }

        let loaderVersion = selectedModLoader == GameLoader.vanilla.displayName ? selectedModLoader : selectedLoaderVersion
        guard !loaderVersion.isEmpty else { return }

        let generatedName = GameNameGenerator.generateGameName(
            gameVersion: selectedGameVersion,
            loaderVersion: loaderVersion,
            modLoader: selectedModLoader
        )
        gameNameValidator.gameName = generatedName
    }
}
