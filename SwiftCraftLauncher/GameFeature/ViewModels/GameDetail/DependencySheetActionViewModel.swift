//
//  DependencySheetActionViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// View model that manages download actions for dependency sheet dialogs, coordinating "download all" and "download main only" flows.
@MainActor
@Observable
final class DependencySheetActionViewModel {
    var error: GlobalError?

    private let isDownloadingAllDependencies: Binding<Bool>
    private let isDownloadingMainResourceOnly: Binding<Bool>

    init(
        isDownloadingAllDependencies: Binding<Bool>,
        isDownloadingMainResourceOnly: Binding<Bool>,
    ) {
        self.isDownloadingAllDependencies = isDownloadingAllDependencies
        self.isDownloadingMainResourceOnly = isDownloadingMainResourceOnly
    }

    /// Downloads only the main resource, excluding dependencies.
    func downloadMainOnly(onDownloadMainOnly: @escaping () async -> Void) {
        Task {
            isDownloadingMainResourceOnly.wrappedValue = true
            await onDownloadMainOnly()
            isDownloadingMainResourceOnly.wrappedValue = false
        }
    }

    /// Downloads the main resource and all its dependencies.
    func downloadAll(onDownloadAll: @escaping () async -> Void) {
        Task {
            isDownloadingAllDependencies.wrappedValue = true
            await onDownloadAll()
            isDownloadingAllDependencies.wrappedValue = false
        }
    }
}
