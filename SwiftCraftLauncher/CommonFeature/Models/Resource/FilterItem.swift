//
//  FilterItem.swift
//  CommonFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// A filter item with an identifier and display name.
struct FilterItem: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
}
