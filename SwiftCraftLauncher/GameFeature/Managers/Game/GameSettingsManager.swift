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
    var globalXms: Int = Defaults.loadInt(forKey: AppConstants.UserDefaultsKeys.globalXms, defaultValue: AppConstants.MemoryDefaults.xms) {
        didSet { Defaults.save(globalXms, forKey: AppConstants.UserDefaultsKeys.globalXms) }
    }

    var globalXmx: Int = Defaults.loadInt(forKey: AppConstants.UserDefaultsKeys.globalXmx, defaultValue: AppConstants.MemoryDefaults.xmx) {
        didSet { Defaults.save(globalXmx, forKey: AppConstants.UserDefaultsKeys.globalXmx) }
    }

    var concurrentDownloads: Int = Defaults.loadInt(forKey: AppConstants.UserDefaultsKeys.concurrentDownloads, defaultValue: 64) {
        didSet { Defaults.save(max(concurrentDownloads, 1), forKey: AppConstants.UserDefaultsKeys.concurrentDownloads) }
    }

    var enableAICrashAnalysis: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableAICrashAnalysis) {
        didSet { Defaults.save(enableAICrashAnalysis, forKey: AppConstants.UserDefaultsKeys.enableAICrashAnalysis) }
    }

    var enableMemoryPressureWarning: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.enableMemoryPressureWarning, defaultValue: true) {
        didSet { Defaults.save(enableMemoryPressureWarning, forKey: AppConstants.UserDefaultsKeys.enableMemoryPressureWarning) }
    }

    var defaultAPISource: DataSource = Defaults.loadEnum(forKey: AppConstants.UserDefaultsKeys.defaultAPISource, defaultValue: .modrinth) {
        didSet { Defaults.save(defaultAPISource.rawValue, forKey: AppConstants.UserDefaultsKeys.defaultAPISource) }
    }

    /// Whether to include snapshot versions in game version selection.
    var includeSnapshotsForGameVersions: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.includeSnapshotsForGameVersions) {
        didSet { Defaults.save(includeSnapshotsForGameVersions, forKey: AppConstants.UserDefaultsKeys.includeSnapshotsForGameVersions) }
    }

    /// Whether to sync the game language to the current launcher language after downloading a new game.
    var syncLanguageForNewGames: Bool = Defaults.loadBool(forKey: AppConstants.UserDefaultsKeys.syncLanguageForNewGames, defaultValue: true) {
        didSet { Defaults.save(syncLanguageForNewGames, forKey: AppConstants.UserDefaultsKeys.syncLanguageForNewGames) }
    }

    /// The default export format for mod packs.
    var defaultModPackExportFormat: ModPackExportFormat = Defaults.loadEnum(forKey: AppConstants.UserDefaultsKeys.defaultModPackExportFormat, defaultValue: .modrinth) {
        didSet { Defaults.save(defaultModPackExportFormat.rawValue, forKey: AppConstants.UserDefaultsKeys.defaultModPackExportFormat) }
    }

    /// The maximum memory allocation based on 70% of physical RAM, rounded to the nearest 512 MB.
    var maximumMemoryAllocation: Int {
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = physicalMemoryBytes / 1_048_576
        let calculatedMax = Int(Double(physicalMemoryMB) * 0.7)
        let roundedMax = (calculatedMax / 512) * 512
        return max(roundedMax, 512)
    }
}
