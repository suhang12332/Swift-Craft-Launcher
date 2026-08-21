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

    let gameSetupService = GameSetupUtil()
    let gameNameValidator: GameNameValidator

    var downloadTaskID: UUID?
    private(set) var isInstallationHidden = false

    let configuration: GameFormConfiguration

    init(configuration: GameFormConfiguration) {
        self.configuration = configuration
        gameNameValidator = GameNameValidator(gameSetupService: gameSetupService)

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
        if isDownloading {
            InstallationTaskManager.shared.cancel(downloadTaskID)
            downloadTaskID = nil
            gameSetupService.downloadState.cancel()
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    func handleConfirm() {
        isInstallationHidden = false
        InstallationTaskManager.shared.cancel(downloadTaskID)
        let taskID = InstallationTaskManager.shared.start { [self] in
            await performConfirmAction()
        }
        downloadTaskID = taskID
        gameSetupService.attachInstallationTask(taskID)
    }

    func updateParentState() {
        configuration.isDownloading.wrappedValue = computeIsDownloading()
        configuration.isFormValid.wrappedValue = computeIsFormValid()
        configuration.isLoadingLoaderVersions.wrappedValue = computeIsLoadingLoaderVersions()

        isDownloading = configuration.isDownloading.wrappedValue
        isFormValid = configuration.isFormValid.wrappedValue
    }

    func performConfirmAction() async {
        configuration.actions.onConfirm()
    }

    func performCancelCleanup() async {
        await MainActor.run {
            gameSetupService.downloadState.reset()
            configuration.actions.onCancel()
        }
    }

    func computeIsDownloading() -> Bool {
        gameSetupService.downloadState.isDownloading
    }

    func computeIsFormValid() -> Bool {
        gameNameValidator.isFormValid
    }

    func computeIsLoadingLoaderVersions() -> Bool {
        false
    }

    func startDownloadTask(_ task: @escaping @MainActor @Sendable () async -> Void) {
        InstallationTaskManager.shared.cancel(downloadTaskID)
        let taskID = InstallationTaskManager.shared.start(operation: task)
        downloadTaskID = taskID
        gameSetupService.attachInstallationTask(taskID)
    }

    func cancelDownloadIfNeeded() {
        if isDownloading {
            InstallationTaskManager.shared.cancel(downloadTaskID)
            downloadTaskID = nil
        } else {
            configuration.actions.onCancel()
        }
    }

    func hideInstallation() {
        guard isDownloading else {
            configuration.actions.onCancel()
            return
        }
        isInstallationHidden = true
        configuration.actions.onCancel()
    }

    func handleNonCriticalError(_ error: GlobalError, message: String) {
        AppLog.game.error("\(message): \(error.localizedDescription)")
        DIContainer.shared.core.errorHandler.handle(error)
    }
}
