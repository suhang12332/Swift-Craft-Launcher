//
//  DIContainer.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine
import Foundation
import MinecraftFriendsKit
import SwiftUI

/// Centralized dependency container that owns all shared service instances.
/// AppServices delegates to this container internally.
final class DIContainer: ObservableObject {
    static let shared = DIContainer()

    // UI

    var ui = UIContainer()

    // Core

    var core = CoreContainer()

    // System

    var system = SystemContainer()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward objectWillChange from nested ObservableObject instances so that
        // @EnvironmentObject consumers pick up state changes (e.g. game running/launching).
        forwardObjectWillChange(from: core.gameStatusManager)
        forwardObjectWillChange(from: ui.themeManager)
        forwardObjectWillChange(from: ui.generalSettingsManager)
        forwardObjectWillChange(from: system.minecraftAuthService)
        forwardObjectWillChange(from: system.yggdrasilAuthService)
        forwardObjectWillChange(from: system.sparkleUpdateService)
        forwardObjectWillChange(from: core.errorHandler)
        forwardObjectWillChange(from: core.cacheInfoManager)

        MainActor.assumeIsolated { [weak self] in
            guard let self else { return }
            forwardObjectWillChange(from: ui.openURLModPackImportPresenter)
            forwardObjectWillChange(from: ui.windowDataStore)
        }
    }

    private func forwardObjectWillChange(from object: some ObservableObject) {
        object.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
