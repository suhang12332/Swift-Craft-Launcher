//
//  GameInfoDetailIOViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// View model for game info detail I/O operations, including local resource scanning and game icon management.
@MainActor
final class GameInfoDetailIOViewModel: ObservableObject {
    private let errorHandler: GlobalErrorHandler
    private let modScanner: ModScanner

    init(
        errorHandler: GlobalErrorHandler = AppServices.errorHandler,
        modScanner: ModScanner = AppServices.modScanner,
    ) {
        self.errorHandler = errorHandler
        self.modScanner = modScanner
    }

    /// Scans the local resource directory and returns a set of detail IDs.
    func scanAllDetailIds(query: String, gameName: String) async -> Set<String> {
        if query.lowercased() == ResourceType.modpack.rawValue {
            return []
        }

        guard let resourceDir = AppPaths.resourceDirectory(for: query, gameName: gameName) else {
            return []
        }

        guard FileManager.default.fileExists(atPath: resourceDir.path) else {
            return []
        }

        do {
            return try await modScanner.scanAllDetailIdsThrowing(in: resourceDir)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.game.error("Failed to scan all resources: \(globalError.localizedDescription)")
            errorHandler.handle(globalError)
            return []
        }
    }

    /// Saves a game icon from a file picker result, returning whether the operation succeeded.
    func saveGameIcon(from result: Result<[URL], Error>, gameName: String) async -> Bool {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                let globalError = GlobalError.validation(
                    i18nKey: "error.validation.no_file_selected",
                    level: .notification,
                )
                errorHandler.handle(globalError)
                return false
            }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification,
                )
                errorHandler.handle(globalError)
                return false
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                try await Task.detached(priority: .userInitiated) {
                    let imageData = try Data(contentsOf: url)
                    let optimizedImageData = GameIconProcessor.optimize(data: imageData)
                    let profileDir = AppPaths.profileDirectory(gameName: gameName)
                    let iconFileName = AppConstants.defaultGameIcon
                    let iconURL = profileDir.appendingPathComponent(iconFileName)
                    try FileManager.default.createDirectory(
                        at: profileDir,
                        withIntermediateDirectories: true,
                    )
                    try optimizedImageData.write(to: iconURL)
                }.value

                AppLog.game.info("Successfully updated game icon: \(gameName)")
                return true
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.game.error("Failed to update game icon: \(globalError.localizedDescription)")
                errorHandler.handle(globalError)
                return false
            }

        case let .failure(error):
            let globalError = GlobalError.from(error)
            errorHandler.handle(globalError)
            return false
        }
    }
}
