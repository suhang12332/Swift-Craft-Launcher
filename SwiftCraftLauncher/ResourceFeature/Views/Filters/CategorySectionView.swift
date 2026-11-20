//
//  CategorySectionView.swift
//  ResourceFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays a section of filter chips with optional overflow handling.
struct CategorySectionView: View {
    let title: String
    let items: [FilterItem]
    @Binding var selectedItems: [String]
    let isLoading: Bool
    var isVersionSection: Bool = false

    var body: some View {
        let (visibleItems, overflowItems) = computeVisibleAndOverflowItems()

        if isVersionSection {
            section(visibleItems: visibleItems, overflowItems: overflowItems) { _ in
                VersionGroupedView(
                    items: items,
                    selectedItems: selectedItems,
                ) { itemId in
                    toggleSelection(for: itemId)
                }
                .frame(maxHeight: SectionViewConstants.defaultPopoverMaxHeight)
                .frame(width: SectionViewConstants.defaultPopoverWidth)
            }
        } else {
            defaultSection(visibleItems: visibleItems, overflowItems: overflowItems)
        }
    }

    private func section(
        visibleItems: [FilterItem],
        overflowItems: [FilterItem],
        @ViewBuilder overflowContentBuilder: @escaping ([FilterItem]) -> some View,
    ) -> some View {
        GenericSectionView(
            title: title,
            items: items,
            isLoading: isLoading,
            chipBuilder: { item in
                chip(for: item)
            },
            overflowContentBuilder: overflowContentBuilder,
            clearAction: clearSelection,
            shouldShowClearButton: { !selectedItems.isEmpty },
            customVisibleItems: visibleItems,
            customOverflowItems: overflowItems,
        )
    }

    private func defaultSection(visibleItems: [FilterItem], overflowItems: [FilterItem]) -> some View {
        GenericSectionView(
            title: title,
            items: items,
            isLoading: isLoading,
            chipBuilder: { item in
                chip(for: item)
            },
            clearAction: clearSelection,
            shouldShowClearButton: { !selectedItems.isEmpty },
            customVisibleItems: visibleItems,
            customOverflowItems: overflowItems,
        )
    }

    private func chip(for item: FilterItem) -> some View {
        FilterChip(
            title: item.name,
            isSelected: selectedItems.contains(item.id),
        ) {
            toggleSelection(for: item.id)
        }
    }

    private func computeVisibleAndOverflowItems() -> ([FilterItem], [FilterItem]) {
        items.computeVisibleAndOverflowItemsByRows(
            maxRows: SectionViewConstants.defaultMaxRows,
            maxWidth: SectionViewConstants.defaultMaxWidth,
        ) { item in
            CGFloat(item.name.count) * SectionViewConstants.defaultEstimatedCharWidth
                + SectionViewConstants.defaultChipPadding
        }
    }

    private func clearSelection() {
        selectedItems.removeAll()
    }

    private func toggleSelection(for id: String) {
        if selectedItems.contains(id) {
            selectedItems.removeAll { $0 == id }
        } else {
            selectedItems.append(id)
        }
    }
}
