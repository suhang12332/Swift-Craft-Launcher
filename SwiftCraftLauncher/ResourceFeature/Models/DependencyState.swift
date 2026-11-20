//
//  DependencyState.swift
//  ResourceFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Tracks the loading and selection state of resource dependencies.
struct DependencyState {
    var dependencies: [ModrinthProjectDetail] = []
    var versions: [String: [ModrinthProjectDetailVersion]] = [:]
    var selected: [String: ModrinthProjectDetailVersion?] = [:]
    var isLoading = false
}
