//
//  GameFormImportViewModel.swift
//  GameFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// View model that prepares mod pack import files by copying them to a temporary directory.
@MainActor
@Observable
final class GameFormImportViewModel {
    init() { }

    /// Copies a selected mod pack file to a temporary directory so it can be
    /// parsed and installed after the file picker's security scope is released.
    /// - Parameter result: The file picker result containing selected URLs.
    /// - Returns: The temporary file URL, or `nil` if preparation fails.
    func prepareModPackFile(from result: Result<[URL], Error>) async -> URL? {
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
                return try await copyToTempDirectory(url: url)
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
            let tempDir = try TemporaryDirectory(purpose: .modpackImport).url
            let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: tempFile)
            return tempFile
        }.value
    }
}
