//
//  OpenURLModPackImportPresenter.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Presents a mod pack import sheet when the app opens a supported file URL.
@MainActor
@Observable
final class OpenURLModPackImportPresenter {
    var showImportSheet = false
    private(set) var preselectedTempFile: URL?

    private let importViewModel = GameFormImportViewModel()

    init() { }

    func handle(url: URL) {
        guard url.isFileURL else { return }
        let supportedExtensions = [
            AppConstants.FileExtensions.zip,
            AppConstants.FileExtensions.mrpack,
        ]
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return }

        Task {
            // Check the region gate before copying or parsing the mod pack, so a blocked
            // import never starts processing in the background.
            if await CommonUtil.isCnGate() {
                DIContainer.shared.core.errorHandler.handle(
                    GlobalError.validation(i18nKey: "region.block.message", level: .popup)
                        .withTitleKey("region.block.title"),
                )
                return
            }

            let mode = await importViewModel.prepareModPackImportMode(from: .success([url]))
            guard case let .modPackImport(file, shouldProcess) = mode else { return }

            preselectedTempFile = file
            showImportSheet = shouldProcess
        }
    }

    func clear() {
        preselectedTempFile = nil
    }
}
