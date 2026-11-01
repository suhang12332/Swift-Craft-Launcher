//
//  BaseGameFormViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation
import SwiftUI

/// Base view model for game form views, providing common download management and form validation.
@MainActor
@Observable
class BaseGameFormViewModel {
    var isDownloading: Bool = false
    var isFormValid: Bool = false
    var triggerConfirm: Bool = false
    var triggerCancel: Bool = false

    let gameInstaller = GameInstaller()
    let gameNameValidator: GameNameValidator

    var gameRepository: GameRepository?
    private let installTasks = InstallTaskCoordinator()

    var isCancellable: Bool {
        !installTasks.isCancelling && (computeIsDownloading() || installTasks.isRunning)
    }

    let configuration: GameFormConfiguration

    init(configuration: GameFormConfiguration) {
        self.configuration = configuration
        gameNameValidator = GameNameValidator()

        setupObservers()
    }

    private func setupObservers() {
        // Observe @Observable GameNameValidator via withObservationTracking
        Task { @MainActor [weak self] in
            while let self {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.gameNameValidator.isFormValid
                        _ = self.gameNameValidator.isGameNameDuplicate
                        _ = self.gameNameValidator.gameName
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled else { break }
                updateParentState()
            }
        }
    }

    func handleCancel() {
        guard isCancellable else {
            configuration.actions.onCancel()
            return
        }

        installTasks.cancel()
        gameInstaller.progress.cancel()
        Task {
            await performCancelCleanup()
        }
    }

    func handleConfirm() {
        startDownloadTask {
            await self.performInstallation()
        }
    }

    func updateParentState() {
        configuration.isDownloading.wrappedValue = computeIsDownloading()
        configuration.isFormValid.wrappedValue = computeIsFormValid()
        configuration.isLoadingLoaderVersions.wrappedValue = computeIsLoadingLoaderVersions()

        isDownloading = configuration.isDownloading.wrappedValue
        isFormValid = configuration.isFormValid.wrappedValue
    }

    func performInstallation() async {
        configuration.actions.onConfirm()
    }

    func completeInstallation() {
        finishDownloadTask()
        configuration.actions.onCancel()
    }

    func performCancelCleanup() async {
        configuration.actions.onCancel()

        await GameArtifactCleaner.cleanupCancelledGame(
            gameName: gameNameValidator.gameName,
            gameRepository: gameRepository,
        )
        gameInstaller.progress.reset()
    }

    func computeIsDownloading() -> Bool {
        gameInstaller.progress.isDownloading
    }

    func computeIsFormValid() -> Bool {
        gameNameValidator.isFormValid
    }

    func computeIsLoadingLoaderVersions() -> Bool {
        false
    }

    func startDownloadTask(_ task: @escaping () async -> Void) {
        installTasks.start(
            onFinish: { [weak self] in
                self?.updateParentState()
            },
            operation: {
                await task()
            },
        )
    }

    func finishDownloadTask() {
        installTasks.finish()
        gameInstaller.progress.reset()
        updateParentState()
    }

    func handleNonCriticalError(_ error: GlobalError, message: String) {
        AppLog.game.error("\(message): \(error.localizedDescription)")
        DIContainer.shared.core.errorHandler.handle(error)
    }
}
