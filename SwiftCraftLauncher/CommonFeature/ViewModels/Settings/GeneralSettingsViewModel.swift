//
//  GeneralSettingsViewModel.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import SwiftUI

/// Manages general application settings including working directory and download preferences.
@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    @Published var showDirectoryPicker = false
    @Published var error: GlobalError?

    @Published var concurrentDownloadsDraft: Double
    @Published var isEditingConcurrentDownloads = false

    private weak var gameRepository: GameRepository?

    init() {
        concurrentDownloadsDraft = Double(DIContainer.shared.ui.generalSettingsManager.concurrentDownloads)
    }

    /// Configures the view model with a game repository reference.
    func configure(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
    }

    /// Returns a display string for a working directory path and game count.
    func workingPathDisplayString(for item: (path: String, count: Int)) -> String {
        let lastComponent = (item.path as NSString).lastPathComponent
        let countStr = String(format: "settings.working_path.game_count".localized(), item.count)
        return "\(lastComponent) (\(countStr))"
    }

    /// Resets the working directory to the default application support path.
    func resetWorkingDirectorySafely() {
        do {
            guard let supportDir = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first?
                .appendingPathComponent(Bundle.main.appName)
            else {
                throw GlobalError.configuration(
                    i18nKey: "error.configuration.app_support_directory_not_found",
                    level: .popup,
                    message: "Application Support directory not found for bundle: \(Bundle.main.appName)",
                )
            }

            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            DIContainer.shared.ui.generalSettingsManager.launcherWorkingDirectory = supportDir.path
            AppLog.common.info("Working directory reset to: \(supportDir.path)")
        } catch {
            present(GlobalError.from(error))
        }
    }

    /// Handles the result from a directory picker.
    func handleDirectoryImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
                guard resourceValues.isDirectory == true, resourceValues.isReadable == true else {
                    throw GlobalError.fileSystem(
                        i18nKey: "error.filesystem.invalid_directory_selected",
                        level: .notification,
                        message: "Selected path is not a readable directory: \(url.path)",
                    )
                }

                DIContainer.shared.ui.generalSettingsManager.launcherWorkingDirectory = url.path
                AppLog.common.info("Working directory set to: \(url.path)")
            } catch {
                present(GlobalError.from(error))
            }
        case let .failure(error):
            present(
                GlobalError.fileSystem(
                    i18nKey: "error.filesystem.directory_selection_failed",
                    level: .notification,
                    message: "Directory selection failed: \(error.localizedDescription)",
                ),
            )
        }
    }

    /// Refreshes working path options when the directory changes.
    func onWorkingDirectoryChanged() {
        Task { [weak self] in
            await self?.gameRepository?.refreshWorkingPathOptions()
        }
    }

    /// Syncs the concurrent downloads draft value with current settings.
    func onAppearSyncConcurrentDownloads() {
        concurrentDownloadsDraft = Double(DIContainer.shared.ui.generalSettingsManager.concurrentDownloads)
    }

    /// Updates the concurrent downloads draft when not actively editing.
    func onConcurrentDownloadsChanged(_ newValue: Int) {
        guard !isEditingConcurrentDownloads else { return }
        concurrentDownloadsDraft = Double(newValue)
    }

    /// Commits the concurrent downloads value when editing ends.
    func commitConcurrentDownloadsIfNeeded(isEditing: Bool) {
        isEditingConcurrentDownloads = isEditing
        if !isEditing {
            DIContainer.shared.ui.generalSettingsManager.concurrentDownloads = Int(concurrentDownloadsDraft.rounded())
        }
    }

    /// Clears the current error state.
    func clearError() {
        error = nil
    }

    private func present(_ globalError: GlobalError) {
        DIContainer.shared.core.errorHandler.handle(globalError)
        error = globalError
    }
}
