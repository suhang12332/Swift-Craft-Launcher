//
//  SectionViewConfigurations.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A protocol defining the configuration for a section view.
protocol SectionViewConfiguration {
    associatedtype Item: Identifiable

    var title: String { get }
    var items: [Item] { get }
    var isLoading: Bool { get }
    var maxItems: Int { get }
    var iconName: String? { get }
}

/// A string wrapper that conforms to Identifiable.
public struct IdentifiableString: Identifiable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
