import SwiftUI

// MARK: - Category Section View
struct CategorySectionView: View {
    // MARK: - Properties
    let title: String
    let items: [FilterItem]
    @Binding var selectedItems: [String]
    let isLoading: Bool
    var isVersionSection: Bool = false

    // MARK: - Body
    var body: some View {
        let (visibleItems, overflowItems) = computeVisibleAndOverflowItems()
        
        return GenericSectionView(
            title: title,
            items: items,
            isLoading: isLoading,
            iconName: nil,
            chipBuilder: { item in
                FilterChip(
                    title: item.name,
                    isSelected: selectedItems.contains(item.id)
                ) { toggleSelection(for: item.id) }
            },
            overflowContentBuilder: isVersionSection ? { _ in
                AnyView(
                    VersionGroupedView(
                        items: items,
                        selectedItems: $selectedItems
                    ) { itemId in
                        toggleSelection(for: itemId)
                    }
                    .frame(maxHeight: SectionViewConstants.defaultPopoverMaxHeight)
                    .frame(width: SectionViewConstants.defaultPopoverWidth)
                )
            } : nil,
            clearAction: {
                clearSelection()
            },
            shouldShowClearButton: {
                !selectedItems.isEmpty
            },
            customVisibleItems: visibleItems,
            customOverflowItems: overflowItems
        )
    }

    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> ([FilterItem], [FilterItem]) {
        return items.computeVisibleAndOverflowItemsByRows(
            maxRows: SectionViewConstants.defaultMaxRows,
            maxWidth: SectionViewConstants.defaultMaxWidth
        ) { item in
            CGFloat(item.name.count) * SectionViewConstants.defaultEstimatedCharWidth
                + SectionViewConstants.defaultChipPadding
        }
    }

    // MARK: - Actions
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
