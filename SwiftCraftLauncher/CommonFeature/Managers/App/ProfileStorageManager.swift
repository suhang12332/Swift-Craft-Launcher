//
//  ProfileStorageManager.swift
//  CommonFeature
//
//  Computes storage usage information for game profiles.
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Manages storage usage calculations for game profiles.
@Observable
final class ProfileStorageManager {
    var storageInfo: ProfileStorageInfo = .init(archiveCount: 0, totalSize: 0)

    private let calculator = ProfileStorageCalculator()

    init() { }

    /// Calculates storage usage for a specific game's profile data.
    /// - Parameter game: The game name to calculate storage usage for.
    func calculateGameStorageInfo(_ game: String) {
        do {
            storageInfo = try calculator.calculateProfileStorage(gameName: game)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.common.error("Failed to calculate game storage info: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }
}
