//
//  ModPackFileExporter.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import CoreTransferable
import SwiftUI
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

/// A file-based `Transferable` that lets `fileExporter` copy an existing
/// archive without loading it into memory as `Data`.
struct ModPackArchiveTransfer: Transferable, Sendable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: ModPackArchiveContentType.mrpack) { item in
            SentTransferredFile(
                item.fileURL,
                allowAccessingOriginalFile: false,
            )
        }
        FileRepresentation(exportedContentType: ModPackArchiveContentType.zip) { item in
            SentTransferredFile(
                item.fileURL,
                allowAccessingOriginalFile: false,
            )
        }
    }
}

/// Applies the `fileExporter` for the prepared archive format.
struct ModPackFileExporter: ViewModifier {
    @Binding var isPresented: Bool
    let prepared: PreparedModPackArchive?
    let onCompletion: (Result<URL, Error>) -> Void
    let onCancellation: () -> Void

    func body(content: Content) -> some View {
        content.fileExporter(
            isPresented: $isPresented,
            item: prepared.map { ModPackArchiveTransfer(fileURL: $0.fileURL) },
            contentTypes: prepared.map { [$0.format.archiveContentType] }
                ?? [ModPackArchiveContentType.zip],
            defaultFilename: prepared?.fileURL.lastPathComponent,
            onCompletion: onCompletion,
            onCancellation: onCancellation,
        )
    }
}
