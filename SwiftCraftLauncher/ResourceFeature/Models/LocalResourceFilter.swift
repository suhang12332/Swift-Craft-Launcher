//
//  LocalResourceFilter.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Filters for displaying local (installed) resources.
enum LocalResourceFilter: String, CaseIterable, Identifiable {
    case all
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "resource.local_filter.all".localized()
        case .disabled:
            return "resource.local_filter.disabled".localized()
        }
    }

    var icon: String {
        switch self {
        case .all:
            return "list.bullet"
        case .disabled:
            return "nosign"
        }
    }
}
