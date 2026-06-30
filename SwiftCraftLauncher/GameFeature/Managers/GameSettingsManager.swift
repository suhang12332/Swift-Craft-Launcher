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
class GameSettingsManager: ObservableObject {
    static let shared = GameSettingsManager()

    private init() {}

    @AppStorage(AppConstants.UserDefaultsKeys.globalXms)
    var globalXms: Int = 512 {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.globalXmx)
    var globalXmx: Int = 4096 {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.enableAICrashAnalysis)
    var enableAICrashAnalysis: Bool = false {
        didSet { objectWillChange.send() }
    }

    @AppStorage(AppConstants.UserDefaultsKeys.defaultAPISource)
    var defaultAPISource: DataSource = .modrinth {
        didSet { objectWillChange.send() }
    }

    /// Whether to include snapshot versions in game version selection.
    @AppStorage(AppConstants.UserDefaultsKeys.includeSnapshotsForGameVersions)
    var includeSnapshotsForGameVersions: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Whether to sync the game language to the current launcher language after downloading a new game.
    @AppStorage(AppConstants.UserDefaultsKeys.syncLanguageForNewGames)
    var syncLanguageForNewGames: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// The default export format for mod packs.
    @AppStorage(AppConstants.UserDefaultsKeys.defaultModPackExportFormat)
    var defaultModPackExportFormat: ModPackExportFormat = .modrinth {
        didSet { objectWillChange.send() }
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
