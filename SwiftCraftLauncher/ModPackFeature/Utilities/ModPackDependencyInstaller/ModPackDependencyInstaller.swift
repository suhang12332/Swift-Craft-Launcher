//
//  ModPackDependencyInstaller.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Installs all required dependencies defined by a modpack.
enum ModPackDependencyInstaller {
    static var downloadSemaphoreValue: Int {
        max(1, DIContainer.shared.ui.gameSettingsManager.concurrentDownloads / 4)
    }

    enum DownloadType {
        case files
        case dependencies
        case overrides
    }
}

// ModPackCounter removed — replaced by shared AtomicCounter actor.
