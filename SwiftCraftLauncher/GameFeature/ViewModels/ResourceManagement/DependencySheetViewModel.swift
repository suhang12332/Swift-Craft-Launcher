//
//  DependencySheetViewModel.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SwiftUI

/// Represents the download state of a single resource dependency.
enum ResourceDownloadState {
    case idle, downloading, success, failed
}

/// View model that manages dependency resolution, download states, and version selection for resource dependencies.
@Observable
final class DependencySheetViewModel {
    var missingDependencies: [ModrinthProjectDetail] = []
    var isLoadingDependencies = true
    var showDependenciesSheet = false
    var dependencyDownloadStates: [String: ResourceDownloadState] = [:]
    var dependencyVersions: [String: [ModrinthProjectDetailVersion]] = [:]
    var selectedDependencyVersion: [String: String] = [:]
    var overallDownloadState: OverallDownloadState = .idle

    /// Represents the aggregate state of all dependency downloads.
    enum OverallDownloadState {
        case idle
        case failed
        case retrying
    }

    var allDependenciesDownloaded: Bool {
        if missingDependencies.isEmpty { return true }

        return missingDependencies.allSatisfy {
            dependencyDownloadStates[$0.id] == .success
        }
    }

    func resetDownloadStates() {
        for dep in missingDependencies {
            dependencyDownloadStates[dep.id] = .idle
        }
        overallDownloadState = .idle
    }

    /// Resets all published properties to their initial values.
    func cleanup() {
        missingDependencies = []
        isLoadingDependencies = true
        dependencyDownloadStates = [:]
        dependencyVersions = [:]
        selectedDependencyVersion = [:]
        overallDownloadState = .idle
    }
}
