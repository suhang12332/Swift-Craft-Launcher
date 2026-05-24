import SwiftUI

@MainActor
final class LauncherImportViewModel: BaseGameFormViewModel {
    @Published var selectedLauncherType: ImportLauncherType = .multiMC
    @Published var selectedLauncherRootPath: URL?
    @Published var scannedInstances: [ScannedLauncherInstance] = []
    @Published var selectedInstanceIDs = Set<String>()
    @Published var isScanning = false
    @Published var isImporting = false {
        didSet {
            updateParentState()
        }
    }
    @Published var importProgress: (fileName: String, completed: Int, total: Int)?
    @Published var currentImportInstanceName: String?
    @Published var activeImportModLoader = GameLoader.vanilla.displayName

    var hasAdjustedSelectionDuringScan = false
    var gameRepository: GameRepository?
    var playerListViewModel: PlayerListViewModel?
    var copyTask: Task<Void, Error>?
    var scanTask: Task<Void, Never>?
    var activeImportGameName: String?

    override init(
        configuration: GameFormConfiguration,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        super.init(configuration: configuration, errorHandler: errorHandler)
    }

    func setup(gameRepository: GameRepository, playerListViewModel: PlayerListViewModel) {
        self.gameRepository = gameRepository
        self.playerListViewModel = playerListViewModel
        refreshDetectedRootAndScan()
        updateParentState()
    }

    func cleanup() {
        scanTask?.cancel()
        scanTask = nil
        copyTask?.cancel()
        copyTask = nil
        downloadTask?.cancel()
        downloadTask = nil

        selectedLauncherRootPath = nil
        scannedInstances = []
        selectedInstanceIDs.removeAll()
        importProgress = nil
        currentImportInstanceName = nil
        activeImportGameName = nil
        activeImportModLoader = GameLoader.vanilla.displayName
        isScanning = false
        isImporting = false
        selectedLauncherType = .multiMC
        gameSetupService.downloadState.reset()
        gameRepository = nil
        playerListViewModel = nil
    }

    override func performConfirmAction() async {
        startDownloadTask {
            await self.importSelectedInstances()
        }
    }

    override func handleCancel() {
        if isScanning || isDownloading || isImporting {
            scanTask?.cancel()
            scanTask = nil
            copyTask?.cancel()
            copyTask = nil
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            Task {
                await self.performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    override func performCancelCleanup() async {
        if let gameName = activeImportGameName {
            do {
                let fileManager = MinecraftFileManager()
                try fileManager.cleanupGameDirectories(gameName: gameName)
            } catch {
                Logger.shared.error("清理游戏文件夹失败: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            activeImportGameName = nil
            currentImportInstanceName = nil
            importProgress = nil
            isScanning = false
            isImporting = false
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    override func computeIsDownloading() -> Bool {
        gameSetupService.downloadState.isDownloading || isImporting
    }

    override func computeIsFormValid() -> Bool {
        !selectedImportInstances.isEmpty && !isScanning && !isImporting
    }

    var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading || isImporting
    }

    var hasSelectedRoot: Bool {
        selectedLauncherRootPath != nil
    }

    var selectedImportInstances: [ScannedLauncherInstance] {
        scannedInstances.filter { selectedInstanceIDs.contains($0.id) }
    }
}
