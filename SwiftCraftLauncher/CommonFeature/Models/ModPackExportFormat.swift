//
//  ModPackExportFormat.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// The export format for a modpack archive.
enum ModPackExportFormat: String, CaseIterable, Codable {
    case modrinth
    case curseforge

    /// The display name shown in the UI.
    var displayName: String {
        switch self {
        case .modrinth:
            return "Modrinth (.mrpack)"
        case .curseforge:
            return "CurseForge (.zip)"
        }
    }

    /// The file extension used when saving the exported modpack.
    var fileExtension: String {
        switch self {
        case .modrinth:
            return AppConstants.FileExtensions.mrpack
        case .curseforge:
            return AppConstants.FileExtensions.zip
        }
    }
}
