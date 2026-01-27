//
//  SectionViewComponents.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//
import SwiftUI

// MARK: - Constants
enum SectionViewConstants {
    static let defaultMaxHeight: CGFloat = 235
    static let defaultVerticalPadding: CGFloat = 4
    static let defaultPopoverWidth: CGFloat = 320
    static let defaultPopoverMaxHeight: CGFloat = 320
    static let defaultPlaceholderCount: Int = 5
    static let defaultMaxItems: Int = 6
}

// MARK: - Overflow Popover Content
struct OverflowPopoverContent<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let maxHeight: CGFloat
    let width: CGFloat
    let content: (Item) -> Content
    
    init(
        items: [Item],
        maxHeight: CGFloat = SectionViewConstants.defaultPopoverMaxHeight,
        width: CGFloat = SectionViewConstants.defaultPopoverWidth,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.maxHeight = maxHeight
        self.width = width
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                FlowLayout {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding()
            }
            .frame(maxHeight: maxHeight)
        }
        .frame(width: width)
    }
}

// MARK: - Loading Placeholder
struct LoadingPlaceholder: View {
    let count: Int
    let iconName: String?
    let maxHeight: CGFloat
    let verticalPadding: CGFloat
    let maxTextWidth: CGFloat?
    let verticalPaddingForChip: CGFloat
    
    init(
        count: Int = SectionViewConstants.defaultPlaceholderCount,
        iconName: String? = nil,
        maxHeight: CGFloat = SectionViewConstants.defaultMaxHeight,
        verticalPadding: CGFloat = SectionViewConstants.defaultVerticalPadding,
        maxTextWidth: CGFloat? = 150,
        verticalPaddingForChip: CGFloat = 4
    ) {
        self.count = count
        self.iconName = iconName
        self.maxHeight = maxHeight
        self.verticalPadding = verticalPadding
        self.maxTextWidth = maxTextWidth
        self.verticalPaddingForChip = verticalPaddingForChip
    }
    
    var body: some View {
        ScrollView {
            FlowLayout {
                ForEach(0..<count, id: \.self) { _ in
                    FilterChip(
                        title: "common.loading".localized(),
                        iconName: iconName,
                        isLoading: true,
                        verticalPadding: verticalPaddingForChip,
                        maxTextWidth: maxTextWidth
                    )
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, verticalPadding)
    }
}

// MARK: - Content With Overflow
struct ContentWithOverflow<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let maxHeight: CGFloat
    let verticalPadding: CGFloat
    let spacing: CGFloat
    let content: (Item) -> Content
    
    init(
        items: [Item],
        maxHeight: CGFloat = SectionViewConstants.defaultMaxHeight,
        verticalPadding: CGFloat = SectionViewConstants.defaultVerticalPadding,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.maxHeight = maxHeight
        self.verticalPadding = verticalPadding
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(items) { item in
                content(item)
            }
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, verticalPadding)
        .padding(.bottom, verticalPadding)
    }
}

// MARK: - Array Extension
extension Array {
    func computeVisibleAndOverflowItems(maxItems: Int) -> ([Element], [Element]) {
        let visibleItems = Array(prefix(maxItems))
        let overflowItems = Array(dropFirst(maxItems))
        return (visibleItems, overflowItems)
    }
}
