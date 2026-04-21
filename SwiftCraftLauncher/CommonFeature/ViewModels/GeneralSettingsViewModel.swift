import AppKit
import Foundation
import SwiftUI

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
        errorHandler: GlobalErrorHandler = AppServices.errorHandler
    ) {
        self.generalSettings = generalSettings
        self.errorHandler = errorHandler
        self.concurrentDownloadsDraft = Double(generalSettings.concurrentDownloads)
    }

    func configure(gameRepository: GameRepository) {
        self.gameRepository = gameRepository
    }

    // MARK: - Working Directory

    func workingPathDisplayString(for item: (path: String, count: Int)) -> String {
        let lastComponent = (item.path as NSString).lastPathComponent
        let countStr = String(format: "settings.working_path.game_count".localized(), item.count)
        return "\(lastComponent) (\(countStr))"
    }

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
                    level: .popup
                )
            }

            try FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            generalSettings.launcherWorkingDirectory = supportDir.path
            Logger.shared.info("工作目录已重置为: \(supportDir.path)")
        } catch {
            present(GlobalError.from(error))
        }
    }

    func handleDirectoryImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
                guard resourceValues.isDirectory == true, resourceValues.isReadable == true else {
                    throw GlobalError.fileSystem(
                        chineseMessage: "选择的路径不是可读的目录",
                        i18nKey: "error.filesystem.invalid_directory_selected",
                        level: .notification
                    )
                }

                generalSettings.launcherWorkingDirectory = url.path
                Logger.shared.info("工作目录已设置为: \(url.path)")
            } catch {
                present(GlobalError.from(error))
            }
        case .failure(let error):
            present(
                GlobalError.fileSystem(
                    chineseMessage: "选择目录失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.directory_selection_failed",
                    level: .notification
                )
            )
        }
    }

    func onWorkingDirectoryChanged() {
        Task { [weak self] in
            await self?.gameRepository?.refreshWorkingPathOptions()
        }
    }

    // MARK: - Concurrent Downloads

    func onAppearSyncConcurrentDownloads() {
        concurrentDownloadsDraft = Double(generalSettings.concurrentDownloads)
    }

    func onConcurrentDownloadsChanged(_ newValue: Int) {
        guard !isEditingConcurrentDownloads else { return }
        concurrentDownloadsDraft = Double(newValue)
    }

    func commitConcurrentDownloadsIfNeeded(isEditing: Bool) {
        isEditingConcurrentDownloads = isEditing
        if !isEditing {
            generalSettings.concurrentDownloads = Int(concurrentDownloadsDraft.rounded())
        }
    }

    // MARK: - Errors

    func clearError() {
        error = nil
    }

    private func present(_ globalError: GlobalError) {
        errorHandler.handle(globalError)
        error = globalError
    }

    // MARK: - Restart

    private func restartAppSafely() {
        do {
            try restartApp()
        } catch {
            present(GlobalError.from(error))
        }
    }

    private func restartApp() throws {
        let appURL = Bundle.main.bundleURL

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appURL.path]

        try task.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}
