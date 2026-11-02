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
            guard let file = await importViewModel.prepareModPackFile(from: .success([url])) else { return }
            preselectedTempFile = file
            showImportSheet = true
        }
    }

    func clear() {
        if let file = preselectedTempFile, TemporaryFile.isTemporary(file) {
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }
        preselectedTempFile = nil
    }
}
