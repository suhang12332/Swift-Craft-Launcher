//
//  ModPackDependencyInstaller.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Installs all required dependencies defined by a modpack.
enum ModPackDependencyInstaller {
    /// How many modpack files may be in flight at once.
    ///
    /// Half the connection setting rather than all of it: a large file splits its
    /// work across several connections, so counting one slot per file keeps the
    /// process-wide connection count near the configured limit instead of
    /// multiplying it. `DownloadBudget` withholds connections once the cap is
    /// reached, and a file that cannot get them simply waits its turn.
    static var downloadSemaphoreValue: Int {
        max(1, DIContainer.shared.ui.gameSettingsManager.concurrentDownloads / 2)
    }

    enum DownloadType {
        case files
        case dependencies
        case overrides
    }
}

// ModPackCounter removed — replaced by shared AtomicCounter actor.
