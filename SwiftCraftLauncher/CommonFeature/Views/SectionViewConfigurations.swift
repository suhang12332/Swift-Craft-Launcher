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

/// Configuration for a category section displaying filter items.
struct CategorySectionConfiguration: SectionViewConfiguration {
    typealias Item = FilterItem

    let title: String
    let items: [FilterItem]
    let isLoading: Bool
    let maxItems: Int
    let iconName: String?

    init(
        title: String,
        items: [FilterItem],
        isLoading: Bool,
        maxItems: Int = SectionViewConstants.defaultMaxItems,
        iconName: String? = nil
    ) {
        self.title = title
        self.items = items
        self.isLoading = isLoading
        self.maxItems = maxItems
        self.iconName = iconName
    }
}

/// Configuration for a file section with generic item type.
struct FileSectionConfiguration<Item: Identifiable>: SectionViewConfiguration {
    let title: String
    let items: [Item]
    let isLoading: Bool
    let maxItems: Int
    let iconName: String?

    init(
        title: String,
        items: [Item],
        isLoading: Bool,
        maxItems: Int = SectionViewConstants.defaultMaxItems,
        iconName: String? = nil
    ) {
        self.title = title
        self.items = items
        self.isLoading = isLoading
        self.maxItems = maxItems
        self.iconName = iconName
    }
}

/// Configuration for a section displaying simple string items.
struct SimpleStringSectionConfiguration: SectionViewConfiguration {
    typealias Item = IdentifiableString

    let title: String
    let items: [IdentifiableString]
    let isLoading: Bool
    let maxItems: Int
    let iconName: String?

    init(
        title: String,
        items: [IdentifiableString],
        isLoading: Bool,
        maxItems: Int = SectionViewConstants.defaultMaxItems,
        iconName: String? = nil
    ) {
        self.title = title
        self.items = items
        self.isLoading = isLoading
        self.maxItems = maxItems
        self.iconName = iconName
    }
}

/// A string wrapper that conforms to Identifiable.
public struct IdentifiableString: Identifiable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
