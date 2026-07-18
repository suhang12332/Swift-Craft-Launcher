//
//  SectionViewComponents.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Constants for section view layout and behavior.
enum SectionViewConstants {
    static let defaultMaxHeight: CGFloat = 235
    static let defaultVerticalPadding: CGFloat = 4
    static let defaultHeaderBottomPadding: CGFloat = 4

    static let defaultPlaceholderCount: Int = 5

    static let defaultPopoverWidth: CGFloat = 320
    static let defaultPopoverMaxHeight: CGFloat = 320

    static let defaultMaxItems: Int = 6
    static let defaultMaxWidth: CGFloat = 320

    static let defaultChipPadding: CGFloat = 16
    static let defaultEstimatedCharWidth: CGFloat = 10
    static let defaultMaxRows: Int = 5
}

/// A view that displays overflow items in a scrollable popover.
struct OverflowPopoverContent<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let maxHeight: CGFloat
    let width: CGFloat
    let content: (Item) -> Content

    init(
        items: [Item],
        maxHeight: CGFloat = SectionViewConstants.defaultPopoverMaxHeight,
        width: CGFloat = SectionViewConstants.defaultPopoverWidth,
        @ViewBuilder content: @escaping (Item) -> Content,
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

/// A view that displays items in a flow layout with a maximum height.
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
        @ViewBuilder content: @escaping (Item) -> Content,
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

extension Array {
    func computeVisibleAndOverflowItems(maxItems: Int) -> ([Element], [Element]) {
        let visibleItems = Array(prefix(maxItems))
        let overflowItems = Array(dropFirst(maxItems))
        return (visibleItems, overflowItems)
    }

    func computeVisibleAndOverflowItemsByRows(
        maxRows: Int = SectionViewConstants.defaultMaxRows,
        maxWidth: CGFloat = SectionViewConstants.defaultMaxWidth,
        estimatedWidth: (Element) -> CGFloat,
    ) -> ([Element], [Element]) {
        var rows: [[Element]] = []
        var currentRow: [Element] = []
        var currentRowWidth: CGFloat = 0

        for item in self {
            let itemWidth = estimatedWidth(item)

            if currentRowWidth + itemWidth > maxWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [item]
                currentRowWidth = itemWidth
            } else {
                currentRow.append(item)
                currentRowWidth += itemWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        let visibleRows = rows.prefix(maxRows)
        let visibleItems = visibleRows.flatMap(\.self)
        let overflowItems = Array(dropFirst(visibleItems.count))

        return (visibleItems, overflowItems)
    }
}
