//
//  GameFormImportViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// View model that prepares mod pack import files by copying them to a temporary directory.
@MainActor
final class GameFormImportViewModel: ObservableObject {
    init() { }

    /// Prepares a mod pack file for import by copying it to a temporary directory.
    /// - Parameter result: The file picker result containing selected URLs.
    /// - Returns: A `GameFormMode` for mod pack import, or `nil` if preparation fails.
    func prepareModPackImportMode(from result: Result<[URL], Error>) async -> GameFormMode? {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return nil }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification,
                )
                DIContainer.shared.core.errorHandler.handle(globalError)
                return nil
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let tempFile = try await copyToTempDirectory(url: url)
                return .modPackImport(file: tempFile, shouldProcess: true)
            } catch {
                DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
                return nil
            }

        case let .failure(error):
            DIContainer.shared.core.errorHandler.handle(GlobalError.from(error))
            return nil
        }
    }

    private func copyToTempDirectory(url: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("modpack_import")
                .appendingPathComponent(UUID().uuidString)

            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true,
            )

            let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: tempFile)
            return tempFile
        }.value
    }
}
