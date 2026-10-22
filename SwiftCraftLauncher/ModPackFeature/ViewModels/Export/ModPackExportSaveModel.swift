//
//  ModPackExportSaveModel.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// A modpack archive that is already written to a temporary file.
///
/// The save flow only carries the file URL so the archive is never loaded
/// into memory as a single `Data` value.
struct PreparedModPackArchive: Sendable {
    let fileURL: URL
    let format: ModPackExportFormat
}

/// Owns the prepared archive while the user chooses a save destination.
@MainActor
@Observable
final class ModPackExportSaveModel {
    private(set) var prepared: PreparedModPackArchive?
    var isExporterPresented = false

    func prepare(_ archive: PreparedModPackArchive) {
        prepared = archive
        isExporterPresented = true
    }

    /// Releases the prepared item. Temp file cleanup is owned by the export view model.
    func cleanup() {
        clearPreparedArchive()
    }

    private func clearPreparedArchive() {
        prepared = nil
        isExporterPresented = false
    }
}
