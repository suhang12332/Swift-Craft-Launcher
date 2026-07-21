//
//  GameSettingsManager.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents available mod data sources.
enum DataSource: String, CaseIterable, Codable {
    case modrinth = "Modrinth"
    case curseforge = "CurseForge"

    var displayName: String {
        switch self {
        case .modrinth:
            return "Modrinth"
        case .curseforge:
            return "CurseForge"
        }
    }

    var localizedName: String {
        "settings.default_api_source.\(rawValue.lowercased())".localized()
    }
}

/// Manages global application settings for the launcher.
@Observable
final class GameSettingsManager {
    var globalXms: Int {
        didSet { UserDefaults.standard.set(globalXms, forKey: AppConstants.UserDefaultsKeys.globalXms) }
    }

    var globalXmx: Int {
        didSet { UserDefaults.standard.set(globalXmx, forKey: AppConstants.UserDefaultsKeys.globalXmx) }
    }

    var enableAICrashAnalysis: Bool {
        didSet { UserDefaults.standard.set(enableAICrashAnalysis, forKey: AppConstants.UserDefaultsKeys.enableAICrashAnalysis) }
    }

    var enableMemoryPressureWarning: Bool {
        didSet { UserDefaults.standard.set(enableMemoryPressureWarning, forKey: AppConstants.UserDefaultsKeys.enableMemoryPressureWarning) }
    }

    var defaultAPISource: DataSource {
        didSet { UserDefaults.standard.set(defaultAPISource.rawValue, forKey: AppConstants.UserDefaultsKeys.defaultAPISource) }
    }

    /// Whether to include snapshot versions in game version selection.
    var includeSnapshotsForGameVersions: Bool {
        didSet { UserDefaults.standard.set(includeSnapshotsForGameVersions, forKey: AppConstants.UserDefaultsKeys.includeSnapshotsForGameVersions) }
    }

    /// Whether to sync the game language to the current launcher language after downloading a new game.
    var syncLanguageForNewGames: Bool {
        didSet { UserDefaults.standard.set(syncLanguageForNewGames, forKey: AppConstants.UserDefaultsKeys.syncLanguageForNewGames) }
    }

    /// The default export format for mod packs.
    var defaultModPackExportFormat: ModPackExportFormat {
        didSet { UserDefaults.standard.set(defaultModPackExportFormat.rawValue, forKey: AppConstants.UserDefaultsKeys.defaultModPackExportFormat) }
    }

    /// The maximum memory allocation based on 70% of physical RAM, rounded to the nearest 512 MB.
    var maximumMemoryAllocation: Int {
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemoryBytes / 1_048_576
        let calculatedMax = Int(Double(physicalMemoryMB) * 0.7)
        let roundedMax = (calculatedMax / 512) * 512
        return max(roundedMax, 512)
    }

    init() {
        let d = UserDefaults.standard
        globalXms = d.object(forKey: AppConstants.UserDefaultsKeys.globalXms) as? Int ?? AppConstants.MemoryDefaults.xms
        globalXmx = d.object(forKey: AppConstants.UserDefaultsKeys.globalXmx) as? Int ?? AppConstants.MemoryDefaults.xmx
        enableAICrashAnalysis = d.bool(forKey: AppConstants.UserDefaultsKeys.enableAICrashAnalysis)
        enableMemoryPressureWarning = d.object(forKey: AppConstants.UserDefaultsKeys.enableMemoryPressureWarning) as? Bool ?? true
        let apiSourceRaw = d.string(forKey: AppConstants.UserDefaultsKeys.defaultAPISource) ?? DataSource.modrinth.rawValue
        defaultAPISource = DataSource(rawValue: apiSourceRaw) ?? .modrinth
        includeSnapshotsForGameVersions = d.bool(forKey: AppConstants.UserDefaultsKeys.includeSnapshotsForGameVersions)
        syncLanguageForNewGames = d.object(forKey: AppConstants.UserDefaultsKeys.syncLanguageForNewGames) as? Bool ?? true
        let exportFormatRaw = d.string(forKey: AppConstants.UserDefaultsKeys.defaultModPackExportFormat) ?? ModPackExportFormat.modrinth.rawValue
        defaultModPackExportFormat = ModPackExportFormat(rawValue: exportFormatRaw) ?? .modrinth
    }
}
