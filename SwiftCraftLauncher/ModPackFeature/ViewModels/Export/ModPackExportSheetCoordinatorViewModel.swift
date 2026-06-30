//
//  ModPackExportSheetCoordinatorViewModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Coordinates the mod pack export sheet presentation and document lifecycle.
///
/// Manages reading the exported mod pack file from disk and presenting
/// it as a shareable document to the user.
@MainActor
final class ModPackExportSheetCoordinatorViewModel: ObservableObject {
    /// A Boolean value indicating whether an export document is ready for sharing.
    @Published var isExporting: Bool = false

    /// The document containing the exported mod pack data, or `nil` if not yet prepared.
    @Published var exportDocument: ModPackDocument?

    /// Reads the exported mod pack file and prepares it for sharing.
    ///
    /// - Parameters:
    ///   - tempFilePath: The URL of the temporary file containing the exported data.
    ///   - onReadFailed: A closure called with an error message if the file read fails.
    func prepareExportDocument(from tempFilePath: URL, onReadFailed: @escaping (String) -> Void) {
        Task {
            do {
                let fileData = try await Task.detached(priority: .userInitiated) {
                    try Data(contentsOf: tempFilePath)
                }.value

                self.exportDocument = ModPackDocument(data: fileData)
                self.isExporting = true
            } catch {
                onReadFailed(error.localizedDescription)
            }
        }
    }

    func cleanupExporterStateIfNeeded(oldValue: Bool, newValue: Bool) {
        if oldValue && !newValue && exportDocument != nil {
            exportDocument = nil
        }
    }

    func reset() {
        exportDocument = nil
        isExporting = false
    }
}
