import Foundation

@MainActor
final class ModPackDownloadSheetCoordinatorViewModel: ObservableObject {
    private var loadTask: Task<Void, Never>?

    func onAppear(
        sheetViewModel: ModPackDownloadSheetViewModel,
        gameRepository: GameRepository,
        projectId: String,
        preloadedDetail: ModrinthProjectDetail?
    ) {
        sheetViewModel.setGameRepository(gameRepository)

        if let preloadedDetail {
            sheetViewModel.applyPreloadedDetail(preloadedDetail)
            return
        }

        loadTask?.cancel()
        loadTask = Task {
            await sheetViewModel.loadProjectDetails(projectId: projectId)
        }
    }

    func onDisappear(
        sheetViewModel: ModPackDownloadSheetViewModel,
        gameSetupService: GameSetupUtil
    ) {
        loadTask?.cancel()
        loadTask = nil

        sheetViewModel.cancelDownloadAndResetStates(gameSetupService: gameSetupService)
        sheetViewModel.cleanupAllData()
    }
}
