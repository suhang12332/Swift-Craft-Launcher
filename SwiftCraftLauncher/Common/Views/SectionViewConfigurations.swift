//
//  SectionViewConfigurations.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//
import SwiftUI

// MARK: - Section View Configuration Protocol
protocol SectionViewConfiguration {
    associatedtype Item: Identifiable
    var title: String { get }
    var items: [Item] { get }
    var isLoading: Bool { get }
    var maxItems: Int { get }
    var iconName: String? { get }
}

// MARK: - Category Section Configuration
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

// MARK: - File Section Configuration
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

// MARK: - Simple String Section Configuration
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

// MARK: - Identifiable String Helper
public struct IdentifiableString: Identifiable {
    public let id: String
    
    public init(id: String) {
        self.id = id
    }
}
