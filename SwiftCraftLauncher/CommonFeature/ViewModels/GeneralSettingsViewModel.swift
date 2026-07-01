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

    private let generalSettings: GeneralSettingsManager
    private let errorHandler: GlobalErrorHandler
    private weak var gameRepository: GameRepository?

    init(
        generalSettings: GeneralSettingsManager = AppServices.generalSettingsManager,
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
    ) {
        self.generalSettings = generalSettings
        self.errorHandler = errorHandler
        concurrentDownloadsDraft = Double(generalSettings.concurrentDownloads)
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
                    chineseMessage: "无法获取应用支持目录",
                    i18nKey: "error.configuration.app_support_directory_not_found",
                    level: .popup,
                )
            }

            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            generalSettings.launcherWorkingDirectory = supportDir.path
            AppLog.common.info("工作目录已重置为: \(supportDir.path)")
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
                        chineseMessage: "选择的路径不是可读的目录",
                        i18nKey: "error.filesystem.invalid_directory_selected",
                        level: .notification,
                    )
                }

                generalSettings.launcherWorkingDirectory = url.path
                AppLog.common.info("工作目录已设置为: \(url.path)")
            } catch {
                present(GlobalError.from(error))
            }
        case let .failure(error):
            present(
                GlobalError.fileSystem(
                    chineseMessage: "选择目录失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.directory_selection_failed",
                    level: .notification,
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
        concurrentDownloadsDraft = Double(generalSettings.concurrentDownloads)
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
            generalSettings.concurrentDownloads = Int(concurrentDownloadsDraft.rounded())
        }
    }

    /// Clears the current error state.
    func clearError() {
        error = nil
    }

    private func present(_ globalError: GlobalError) {
        errorHandler.handle(globalError)
        error = globalError
    }
}
