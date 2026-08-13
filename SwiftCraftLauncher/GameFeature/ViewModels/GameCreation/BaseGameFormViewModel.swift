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

    var downloadTask: Task<Void, Error>?

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
            downloadTask?.cancel()
            downloadTask = nil
            gameSetupService.downloadState.cancel()
            Task {
                await performCancelCleanup()
            }
        } else {
            configuration.actions.onCancel()
        }
    }

    func handleConfirm() {
        downloadTask?.cancel()
        downloadTask = Task {
            await performConfirmAction()
        }
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

    func startDownloadTask(_ task: @escaping () async -> Void) {
        downloadTask?.cancel()
        downloadTask = Task {
            await task()
        }
    }

    func cancelDownloadIfNeeded() {
        if isDownloading {
            downloadTask?.cancel()
            downloadTask = nil
        } else {
            configuration.actions.onCancel()
        }
    }

    func handleNonCriticalError(_ error: GlobalError, message: String) {
        AppLog.game.error("\(message): \(error.localizedDescription)")
        DIContainer.shared.core.errorHandler.handle(error)
    }
}
