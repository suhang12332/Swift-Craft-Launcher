import Foundation

@MainActor
final class GameFormImportViewModel: ObservableObject {
    func prepareModPackImportMode(from result: Result<[URL], Error>) async -> GameFormMode? {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return nil }

            guard url.startAccessingSecurityScopedResource() else {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "无法访问所选文件",
                    i18nKey: "error.filesystem.file_access_failed",
                    level: .notification
                )
                GlobalErrorHandler.shared.handle(globalError)
                return nil
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let tempFile = try await copyToTempDirectory(url: url)
                return .modPackImport(file: tempFile, shouldProcess: true)
            } catch {
                GlobalErrorHandler.shared.handle(GlobalError.from(error))
                return nil
            }

        case .failure(let error):
            GlobalErrorHandler.shared.handle(GlobalError.from(error))
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
                withIntermediateDirectories: true
            )

            let tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: tempFile)
            return tempFile
        }.value
    }
}
