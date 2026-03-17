import Foundation
import SwiftUI
import os

@MainActor
final class AddOrDeleteResourceButtonViewModel: ObservableObject {
    @Published var addButtonState: ModrinthDetailCardView.AddButtonState = .idle
    @Published var isUpdateButtonLoading = false
    @Published var showDeleteAlert = false

    @Published var activeAlert: ResourceButtonAlertType?
    @Published var showGlobalResourceSheet = false
    @Published var showModPackDownloadSheet = false
    @Published var showGameResourceInstallSheet = false

    @Published var preloadedDetail: ModrinthProjectDetail?
    @Published var preloadedCompatibleGames: [GameVersionInfo] = []

    @Published var isDisabled = false
    @Published var currentFileName: String?
    @Published var hasDownloadedInSheet = false
    @Published var oldFileNameForUpdate: String?

    private let project: ModrinthProject
    private let selectedVersions: [String]
    private let selectedLoaders: [String]
    private let gameInfo: GameVersionInfo?
    private let query: String
    private let type: Bool

    private let onResourceChanged: (() -> Void)?
    private let onToggleDisableState: ((Bool) -> Void)?
    private let onResourceUpdated: ((String, String, String, String?) -> Void)?
    private let setIsResourceDisabled: (Bool) -> Void
    private let addScannedHash: (String) -> Void

    private var gameRepository: GameRepository?
    private var playerListViewModel: PlayerListViewModel?

    init(
        project: ModrinthProject,
        selectedVersions: [String],
        selectedLoaders: [String],
        gameInfo: GameVersionInfo?,
        query: String,
        type: Bool,
        onResourceChanged: (() -> Void)?,
        onResourceUpdated: ((String, String, String, String?) -> Void)?,
        onToggleDisableState: ((Bool) -> Void)?,
        setIsResourceDisabled: @escaping (Bool) -> Void,
        addScannedHash: @escaping (String) -> Void
    ) {
        self.project = project
        self.selectedVersions = selectedVersions
        self.selectedLoaders = selectedLoaders
        self.gameInfo = gameInfo
        self.query = query
        self.type = type
        self.onResourceChanged = onResourceChanged
        self.onResourceUpdated = onResourceUpdated
        self.onToggleDisableState = onToggleDisableState
        self.setIsResourceDisabled = setIsResourceDisabled
        self.addScannedHash = addScannedHash
    }

    func setDependencies(
        gameRepository: GameRepository,
        playerListViewModel: PlayerListViewModel
    ) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
    }

    func onAppear(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        if type == false {
            addButtonState = .installed
            if currentFileName == nil {
                currentFileName = project.fileName
            }
            updateDisableState()
            checkForUpdate()
        } else {
            updateButtonState(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
        }
    }

    func onScannedDetailIdsChanged(selectedItem: SidebarItem, scannedDetailIds: Set<String>) {
        guard type else { return }
        updateButtonState(selectedItem: selectedItem, scannedDetailIds: scannedDetailIds)
    }

    func handleUpdateTap() {
        guard type == false else { return }
        oldFileNameForUpdate = currentFileName ?? project.fileName
        isUpdateButtonLoading = true
        Task { await loadGameResourceInstallDetailBeforeOpeningSheet() }
    }

    func handlePrimaryTap(selectedItem: SidebarItem) {
        if case .game = selectedItem {
            handlePrimaryTapInGame()
        } else if case .resource = selectedItem {
            handlePrimaryTapInResource()
        }
    }

    private func handlePrimaryTapInGame() {
        switch addButtonState {
        case .idle:
            if query == ResourceType.modpack.rawValue {
                addButtonState = .loading
                Task { await loadModPackDetailBeforeOpeningSheet() }
                return
            }
            addButtonState = .loading
            Task { await loadGameResourceInstallDetailBeforeOpeningSheet() }
        case .installed, .update:
            if type == false { showDeleteAlert = true }
        default:
            break
        }
    }

    private func handlePrimaryTapInResource() {
        switch addButtonState {
        case .idle:
            if type {
                if query == ResourceType.modpack.rawValue {
                    if playerListViewModel?.currentPlayer == nil {
                        activeAlert = .noPlayer
                        return
                    }
                    addButtonState = .loading
                    Task { await loadModPackDetailBeforeOpeningSheet() }
                    return
                }

                if gameRepository?.games.isEmpty ?? true {
                    activeAlert = .noGame
                    return
                }
            } else {
                if query == ResourceType.modpack.rawValue {
                    addButtonState = .loading
                    Task { await loadModPackDetailBeforeOpeningSheet() }
                    return
                }
            }

            addButtonState = .loading
            Task { await loadProjectDetailBeforeOpeningSheet() }
        case .installed, .update:
            if type == false { showDeleteAlert = true }
        default:
            break
        }
    }

    func confirmDelete() {
        deleteFile(fileName: project.fileName)
    }

    func deleteFile(fileName: String?, isUpdate: Bool = false) {
        let queryLowercased = query.lowercased()

        if queryLowercased == ResourceType.modpack.rawValue || !AppConstants.validResourceTypes.contains(queryLowercased) {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：不支持删除此类型的资源",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        guard let gameInfo = gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法删除文件：游戏信息或资源目录无效",
                i18nKey: "error.configuration.delete_file_failed",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        guard let fileName else {
            let globalError = GlobalError.resource(
                chineseMessage: "无法删除文件：缺少文件名信息",
                i18nKey: "error.resource.file_name_missing",
                level: .notification
            )
            Logger.shared.error("删除文件失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            return
        }

        let fileURL = resourceDir.appendingPathComponent(fileName)
        GameResourceHandler.performDelete(fileURL: fileURL)
        if !isUpdate { onResourceChanged?() }
    }

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

    func handleInstallSuccess(newFileName: String?, newHash: String?) {
        hasDownloadedInSheet = true
        if let newHash { addScannedHash(newHash) }

        let wasUpdate = (oldFileNameForUpdate != nil)
        let oldF = oldFileNameForUpdate

        if let old = oldF {
            deleteFile(fileName: old, isUpdate: true)
            oldFileNameForUpdate = nil
        }

        if wasUpdate, let new = newFileName, let old = oldF {
            onResourceUpdated?(project.projectId, old, new, newHash)
            currentFileName = new
        } else if !type {
            currentFileName = nil
        }

        if type == false {
            checkForUpdate()
        } else {
            addButtonState = .installed
        }

        preloadedDetail = nil
    }

    func toggleDisableState() {
        guard let gameInfo = gameInfo,
              let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameInfo.gameName)
        else {
            Logger.shared.error("切换资源启用状态失败：资源目录不存在")
            return
        }

        let fileName = currentFileName ?? project.fileName
        guard let fileName else {
            Logger.shared.error("切换资源启用状态失败：缺少文件名")
            return
        }

        do {
            let newFileName = try ResourceEnableDisableManager.toggleDisableState(
                fileName: fileName,
                resourceDir: resourceDir
            )
            currentFileName = newFileName
            isDisabled = ResourceEnableDisableManager.isDisabled(fileName: newFileName)
            setIsResourceDisabled(isDisabled)
            onToggleDisableState?(isDisabled)

            if !isDisabled && type == false {
                checkForUpdate()
            }
        } catch {
            Logger.shared.error("切换资源启用状态失败: \(error.localizedDescription)")
        }
    }

    private func updateDisableState() {
        let fileName = currentFileName ?? project.fileName
        isDisabled = ResourceEnableDisableManager.isDisabled(fileName: fileName)
        setIsResourceDisabled(isDisabled)
    }

    private func loadProjectDetailBeforeOpeningSheet() async {
        defer { addButtonState = .idle }

        guard let gameRepository else {
            addButtonState = .idle
            return
        }

        let result: (detail: ModrinthProjectDetail, compatibleGames: [GameVersionInfo])?
        if query == ResourceType.minecraftJavaServer.rawValue {
            result = await ResourceDetailLoader.loadMinecraftJavaServerDetail(
                projectId: project.projectId,
                gameRepository: gameRepository,
                resourceType: query
            )
        } else {
            result = await ResourceDetailLoader.loadProjectDetail(
                projectId: project.projectId,
                gameRepository: gameRepository,
                resourceType: query
            )
        }

        guard let unwrappedResult = result else { return }
        preloadedDetail = unwrappedResult.detail
        preloadedCompatibleGames = unwrappedResult.compatibleGames
        showGlobalResourceSheet = true
    }

    private func loadModPackDetailBeforeOpeningSheet() async {
        defer { addButtonState = .idle }

        guard let detail = await ResourceDetailLoader.loadModPackDetail(projectId: project.projectId) else { return }
        preloadedDetail = detail
        showModPackDownloadSheet = true
    }

    private func loadGameResourceInstallDetailBeforeOpeningSheet() async {
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
                  resourceType: query
              )
        else { return }

        preloadedDetail = result.detail
        if preloadedDetail != nil {
            showGameResourceInstallSheet = true
        }
    }

    private func checkForUpdate() {
        guard let gameInfo = gameInfo,
              type == false,
              !isDisabled,
              !project.projectId.hasPrefix("local_") && !project.projectId.hasPrefix("file_")
        else { return }

        Task {
            let result = await ModUpdateChecker.checkForUpdate(
                project: project,
                gameInfo: gameInfo,
                resourceType: query
            )
            if result.hasUpdate {
                addButtonState = .update
            } else {
                addButtonState = .installed
            }
        }
    }
}
