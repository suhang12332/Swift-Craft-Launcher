import Foundation

@MainActor
final class LauncherImportFolderPickerViewModel: ObservableObject {
    private let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    func handleFolderSelection(
        _ result: Result<[URL], Error>,
        launcherName: String,
        validateInstance: (URL) -> Bool,
        setSelectedInstancePath: (URL) -> Void,
        autoFillGameNameIfNeeded: () -> Void
    ) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                errorHandler.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "无法访问所选文件夹",
                        i18nKey: "error.filesystem.file_access_failed",
                        level: .notification
                    )
                )
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard validateInstance(url) else {
                errorHandler.handle(
                    GlobalError.fileSystem(
                        chineseMessage: "选择的文件夹不是有效的 \(launcherName) 实例",
                        i18nKey: "error.filesystem.invalid_instance_path",
                        level: .notification
                    )
                )
                return
            }

            setSelectedInstancePath(url)
            autoFillGameNameIfNeeded()
            Logger.shared.info("成功选择 \(launcherName) 实例路径: \(url.path)")

        case .failure(let error):
            errorHandler.handle(GlobalError.from(error))
        }
    }
}
