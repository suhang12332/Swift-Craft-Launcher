import Foundation

@MainActor
final class PlayerSettingsViewModel: ObservableObject {
    @Published var isDownloadingAuthlibInjector: Bool = false
    @Published var authlibInjectorExists: Bool = false
    private let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    func refreshAuthlibInjectorExists() {
        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )
        authlibInjectorExists = FileManager.default.fileExists(atPath: authlibInjectorJarURL.path)
    }

    func downloadAuthlibInjector() async {
        guard !isDownloadingAuthlibInjector else { return }
        isDownloadingAuthlibInjector = true
        defer { isDownloadingAuthlibInjector = false }

        let authlibInjectorJarURL = AppPaths.authDirectory.appendingPathComponent(
            AppConstants.AuthlibInjector.jarFileName
        )

        do {
            let downloadURL = URLConfig.API.AuthlibInjector.download
            _ = try await DownloadManager.downloadFile(
                urlString: downloadURL.absoluteString,
                destinationURL: authlibInjectorJarURL,
                expectedSha1: nil
            )
            authlibInjectorExists = true
        } catch {
            let globalError = GlobalError.download(
                chineseMessage: "下载 authlib-injector 失败: \(error.localizedDescription)",
                i18nKey: "error.download.authlib_injector_failed",
                level: .notification
            )
            errorHandler.handle(globalError)
        }
    }
}
