//
//  SelectionState.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit

/// Represents the tri-state selection state of a file tree node.
enum SelectionState {
    case unselected
    case some
    case all

    /// The corresponding NSControl state value.
    var controlState: NSControl.StateValue {
        switch self {
        case .unselected:
            return .off
        case .all:
            return .on
        case .some:
            return .mixed
        }
    }
}
