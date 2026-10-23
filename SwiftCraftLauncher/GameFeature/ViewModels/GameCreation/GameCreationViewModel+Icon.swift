//
//  GameCreationViewModel+Icon.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// Extension providing icon image picker and drag-and-drop handling for `GameCreationViewModel`.
extension GameCreationViewModel {
    func handleImagePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else {
                handleNonCriticalError(
                    GlobalError.validation(
                        i18nKey: "error.validation.no_file_selected",
                        level: .notification,
                    ),
                    message: "error.image.pick.failed".localized(),
                )
                return
            }
            guard url.startAccessingSecurityScopedResource() else {
                handleFileAccessError(URLError(.cannotOpenFile), context: "Image file")
                return
            }
            Task {
                let result: Result<(Data, URL), Error> = await Task.detached(priority: .userInitiated) {
                    do {
                        let data = try Data(contentsOf: url)
                        let optimizedData = GameIconProcessor.optimize(data: data)
                        let temporary = try TemporaryFile(
                            purpose: .gameIconPreview,
                            fileName: "\(UUID().uuidString).png",
                        )
                        try temporary.write(optimizedData)
                        return .success((optimizedData, temporary.url))
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
                case let .failure(error):
                    handleFileReadError(error, context: "Image file")
                }
            }

        case let .failure(error):
            let globalError = GlobalError.from(error)
            handleNonCriticalError(
                globalError,
                message: "error.image.pick.failed".localized(),
            )
        }
    }

    func handleImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else {
            AppLog.game.error("Image drag-and-drop failed: no provider")
            return false
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier,
            ) { data, error in
                if let error {
                    let globalError = GlobalError.from(error)
                    Task { @MainActor in
                        self.handleNonCriticalError(
                            globalError,
                            message: "error.image.load.drag.failed".localized(),
                        )
                    }
                    return
                }

                if let data {
                    Task { @MainActor in
                        let optimizedData = GameIconProcessor.optimize(data: data)
                        let result: URL? = await Task.detached(priority: .userInitiated) {
                            do {
                                let temporary = try TemporaryFile(
                                    purpose: .gameIconPreview,
                                    fileName: "\(UUID().uuidString).png",
                                )
                                try temporary.write(optimizedData)
                                return temporary.url
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
                                    userInfo: nil,
                                ),
                                context: "Image save",
                            )
                        }
                    }
                }
            }
            return true
        }
        AppLog.game.error("Image drag-and-drop failed: unsupported type")
        return false
    }
}
