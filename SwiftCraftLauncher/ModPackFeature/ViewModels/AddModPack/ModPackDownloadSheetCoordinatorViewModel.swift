//
//  ModPackDownloadSheetCoordinatorViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Coordinates the lifecycle of the mod pack download sheet.
///
/// Manages loading project details when the sheet appears and
/// cleaning up resources when it disappears.
@MainActor
final class ModPackDownloadSheetCoordinatorViewModel: ObservableObject {
    private var loadTask: Task<Void, Never>?

    /// Initializes the sheet view model and loads project details.
    ///
    /// - Parameters:
    ///   - sheetViewModel: The view model driving the download sheet UI.
    ///   - gameRepository: The repository containing installed game instances.
    ///   - projectId: The Modrinth or CurseForge project identifier.
    ///   - preloadedDetail: Pre-fetched project details, if available.
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

    /// Cleans up resources when the sheet disappears.
    ///
    /// Cancels any in-progress load task, aborts active downloads,
    /// and clears all transient state.
    ///
    /// - Parameters:
    ///   - sheetViewModel: The view model driving the download sheet UI.
    ///   - gameSetupService: The service used to set up game instances.
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
