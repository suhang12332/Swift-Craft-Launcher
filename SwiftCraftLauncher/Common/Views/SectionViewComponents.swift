//
//  SectionViewComponents.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant
//
import SwiftUI

// MARK: - Constants
enum SectionViewConstants {
    // 布局常量
    static let defaultMaxHeight: CGFloat = 235
    static let defaultVerticalPadding: CGFloat = 4
    static let defaultHeaderBottomPadding: CGFloat = 4

    // 占位符常量
    static let defaultPlaceholderCount: Int = 5

    // 弹窗常量
    static let defaultPopoverWidth: CGFloat = 320
    static let defaultPopoverMaxHeight: CGFloat = 320

    // 项目显示常量
    static let defaultMaxItems: Int = 6
    static let defaultMaxWidth: CGFloat = 320

    // Chip 相关常量（用于行计算）
    static let defaultChipPadding: CGFloat = 16
    static let defaultEstimatedCharWidth: CGFloat = 10
    static let defaultMaxRows: Int = 5
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
    /// 基于最大项目数计算可见和溢出项
    func computeVisibleAndOverflowItems(maxItems: Int) -> ([Element], [Element]) {
        let visibleItems = Array(prefix(maxItems))
        let overflowItems = Array(dropFirst(maxItems))
        return (visibleItems, overflowItems)
    }

    /// 基于行数和宽度计算可见和溢出项（用于 CategorySectionView）
    func computeVisibleAndOverflowItemsByRows(
        maxRows: Int = SectionViewConstants.defaultMaxRows,
        maxWidth: CGFloat = SectionViewConstants.defaultMaxWidth,
        estimatedWidth: (Element) -> CGFloat
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
        let visibleItems = visibleRows.flatMap { $0 }
        let overflowItems = Array(dropFirst(visibleItems.count))

        return (visibleItems, overflowItems)
    }
}
