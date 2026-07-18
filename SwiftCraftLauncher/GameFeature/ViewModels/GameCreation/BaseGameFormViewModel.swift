//
//  BaseGameFormViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import SwiftUI

/// Base view model for game form views, providing common download management and form validation.
@MainActor
class BaseGameFormViewModel: ObservableObject, GameFormStateProtocol {
    @Published var isDownloading: Bool = false
    @Published var isFormValid: Bool = false
    @Published var triggerConfirm: Bool = false
    @Published var triggerCancel: Bool = false

    let gameSetupService = GameSetupUtil()
    let gameNameValidator: GameNameValidator

    var downloadTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    let configuration: GameFormConfiguration

    init(configuration: GameFormConfiguration) {
        self.configuration = configuration
        gameNameValidator = GameNameValidator(gameSetupService: gameSetupService)

        setupObservers()
        updateParentState()
    }

    private func setupObservers() {
        gameNameValidator.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateParentState()
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        gameSetupService.objectWillChange
            .sink { [weak self] in
                DispatchQueue.main.async {
                    self?.updateParentState()
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
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
        let newIsDownloading = computeIsDownloading()
        let newIsFormValid = computeIsFormValid()
        let newIsLoadingLoaderVersions = computeIsLoadingLoaderVersions()

        DispatchQueue.main.async { [weak self] in
            self?.configuration.isDownloading.wrappedValue = newIsDownloading
            self?.configuration.isFormValid.wrappedValue = newIsFormValid
            self?.configuration.isLoadingLoaderVersions.wrappedValue = newIsLoadingLoaderVersions

            self?.isDownloading = newIsDownloading
            self?.isFormValid = newIsFormValid
        }
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
