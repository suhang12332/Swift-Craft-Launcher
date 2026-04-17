import Foundation
import UniformTypeIdentifiers

extension GameCreationViewModel {
    // MARK: - Image Handling

    func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                handleNonCriticalError(
                    GlobalError.validation(
                        chineseMessage: "未选择文件",
                        i18nKey: "error.validation.no_file_selected",
                        level: .notification
                    ),
                    message: "error.image.pick.failed".localized()
                )
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                handleFileAccessError(URLError(.cannotOpenFile), context: "图片文件")
                return
            }
            Task {
                let result: Result<(Data, URL), Error> = await Task.detached(priority: .userInitiated) {
                    do {
                        let data = try Data(contentsOf: url)
                        let optimizedData = GameIconProcessor.optimize(data: data)
                        let tempDir = FileManager.default.temporaryDirectory
                        let tempURL = tempDir.appendingPathComponent("\(UUID().uuidString).png")
                        try optimizedData.write(to: tempURL)
                        return .success((optimizedData, tempURL))
                    } catch {
                        return .failure(error)
                    }
                }.value
                url.stopAccessingSecurityScopedResource()
                switch result {
                case .success(let (dataToWrite, tempURL)):
                    pendingIconURL = tempURL
                    pendingIconData = dataToWrite
                    iconImage = nil
                case .failure(let error):
                    handleFileReadError(error, context: "图片文件")
                }
            }

        case .failure(let error):
            let globalError = GlobalError.from(error)
            handleNonCriticalError(
                globalError,
                message: "error.image.pick.failed".localized()
            )
        }
    }

    func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            Logger.shared.error("图片拖放失败：没有提供者")
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { data, error in
                if let error = error {
                    DispatchQueue.main.async {
                        let globalError = GlobalError.from(error)
                        self.handleNonCriticalError(
                            globalError,
                            message: "error.image.load.drag.failed".localized()
                        )
                    }
                    return
                }

                if let data = data {
                    Task { @MainActor in
                        let optimizedData = GameIconProcessor.optimize(data: data)
                        let result: URL? = await Task.detached(priority: .userInitiated) {
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent("\(UUID().uuidString).png")
                            do {
                                try optimizedData.write(to: tempURL)
                                return tempURL
                            } catch {
                                return nil
                            }
                        }.value
                        if let tempURL = result {
                            self.pendingIconURL = tempURL
                            self.pendingIconData = optimizedData
                            self.iconImage = nil
                        } else {
                            self.handleFileReadError(
                                NSError(
                                    domain: NSCocoaErrorDomain,
                                    code: NSFileWriteUnknownError,
                                    userInfo: nil
                                ),
                                context: "图片保存"
                            )
                        }
                    }
                }
            }
            return true
        }
        Logger.shared.warning("图片拖放失败：不支持的类型")
        return false
    }
}
