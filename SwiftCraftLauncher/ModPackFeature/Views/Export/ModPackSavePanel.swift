//
//  ModPackSavePanel.swift
//  ModPackFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import UniformTypeIdentifiers

enum ModPackArchiveContentType {
    static let mrpack = UTType(importedAs: "com.modrinth.mrpack")
    static let zip: UTType = .zip
}

extension ModPackExportFormat {
    var archiveContentType: UTType {
        switch self {
        case .modrinth:
            ModPackArchiveContentType.mrpack
        case .curseforge:
            ModPackArchiveContentType.zip
        }
    }
}

/// Presents a save panel and copies an already-written archive to the location
/// selected by the user.
///
/// The archive is copied directly between file URLs, so memory usage stays
/// constant regardless of the archive size.
///
/// `fileExporter(isPresented:item:contentTypes:defaultFilename:...)` crashes in
/// `-[NSFileWrapper setPreferredFilename:]` when exporting `.zip`-based content
/// types on newer macOS versions, so the save panel is driven by AppKit instead.
@MainActor
enum ModPackSavePanel {
    static func present(
        fileURL: URL,
        format: ModPackExportFormat,
        completion: @escaping (Result<URL, Error>) -> Void,
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.archiveContentType]
        panel.nameFieldStringValue = fileURL.lastPathComponent
        panel.isExtensionHidden = false

        panel.begin { response in
            guard response == .OK, let destinationURL = panel.url else {
                completion(.failure(CancellationError()))
                return
            }

            do {
                try copyArchive(from: fileURL, to: destinationURL)
                completion(.success(destinationURL))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func copyArchive(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
}
