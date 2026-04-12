import Foundation

extension AddOrDeleteResourceButtonViewModel {
    func updateButtonState(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        if type == false {
            addButtonState = .installed
            return
        }

        let queryLowercased = query.lowercased()

        guard queryLowercased != ResourceType.modpack.rawValue,
              AppConstants.validResourceTypes.contains(queryLowercased)
        else {
            addButtonState = .idle
            return
        }

        guard case .game = selectedItem else {
            addButtonState = .idle
            return
        }

        addButtonState = .loading

        Task {
            let installed = await ResourceInstallationChecker.checkInstalledStateForServerMode(
                project: project,
                resourceType: queryLowercased,
                installedHashes: scannedDetailIds,
                selectedVersions: selectedVersions,
                selectedLoaders: selectedLoaders,
                gameInfo: gameInfo
            )
            addButtonState = installed ? .installed : .idle
        }
    }

    func onGlobalResourceSheetDismiss() {
        addButtonState = .idle
        preloadedDetail = nil
        preloadedCompatibleGames = []
    }

    func onModPackDownloadSheetDismiss() {
        addButtonState = .idle
        preloadedDetail = nil
    }

    func onGameResourceInstallSheetDismiss() {
        isUpdateButtonLoading = false

        if !hasDownloadedInSheet {
            if oldFileNameForUpdate == nil {
                addButtonState = .idle
            }
            oldFileNameForUpdate = nil
        }

        hasDownloadedInSheet = false
        preloadedDetail = nil
    }

    func loadProjectDetailBeforeOpeningSheet() async {
        defer { addButtonState = .idle }

        guard let gameRepository else {
            addButtonState = .idle
            return
        }

        guard let result = await ResourceDetailLoader.loadProjectDetail(
            projectId: project.projectId,
            gameRepository: gameRepository,
            resourceType: query
        ) else {
            return
        }

        preloadedDetail = result.detail
        preloadedCompatibleGames = result.compatibleGames
        showGlobalResourceSheet = true
    }

    func loadModPackDetailBeforeOpeningSheet() async {
        defer { addButtonState = .idle }

        guard let detail = await ResourceDetailLoader.loadModPackDetail(projectId: project.projectId) else { return }
        preloadedDetail = detail
        showModPackDownloadSheet = true
    }

    func loadGameResourceInstallDetailBeforeOpeningSheet() async {
        guard gameInfo != nil else {
            addButtonState = .idle
            return
        }

        defer {
            isUpdateButtonLoading = false
            if oldFileNameForUpdate == nil {
                addButtonState = .idle
            }
        }

        hasDownloadedInSheet = false

        guard let gameRepository,
              let result = await ResourceDetailLoader.loadProjectDetail(
                  projectId: project.projectId,
                  gameRepository: gameRepository,
                  resourceType: query,
                  skipCompatibleGameResolution: true
              )
        else { return }

        preloadedDetail = result.detail
        if preloadedDetail != nil {
            showGameResourceInstallSheet = true
        }
    }
}
