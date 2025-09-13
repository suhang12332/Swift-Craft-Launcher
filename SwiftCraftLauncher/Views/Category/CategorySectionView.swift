import SwiftUI

// MARK: - Constants
private enum CategorySectionConstants {
    static let maxHeight: CGFloat = 235
    static let verticalPadding: CGFloat = 4
    static let headerBottomPadding: CGFloat = 4
    static let placeholderCount: Int = 5
    static let popoverWidth: CGFloat = 320
    static let popoverMaxHeight: CGFloat = 320
    static let chipPadding: CGFloat = 16
    static let estimatedCharWidth: CGFloat = 10
    static let maxRows: Int = 5
    static let maxWidth: CGFloat = 320
}

// MARK: - Category Section View
struct CategorySectionView: View {
    // MARK: - Properties
    let title: String
    let items: [FilterItem]
    @Binding var selectedItems: [String]
    let isLoading: Bool
    var isVersionSection: Bool = false

    @State private var showOverflowPopover = false

    // MARK: - Body
    var body: some View {
        VStack {
            headerView
            if isLoading {
                loadingPlaceholder
            } else {
                contentWithOverflow
            }
        }
    }

    // MARK: - Header Views
    private var headerView: some View {
        let (_, overflowItems) = computeVisibleAndOverflowItems()
        return HStack {
            headerTitle
            if !overflowItems.isEmpty {
                overflowButton(overflowItems: overflowItems)
            }
            Spacer()
            clearButton
        }
        .padding(.bottom, CategorySectionConstants.headerBottomPadding)
    }

    private var headerTitle: some View {
        LabeledContent {
            if !selectedItems.isEmpty {
                selectionCountBadge
            }
        } label: {
            Text(title.localized())
                .font(.headline)
        }
    }

    private var selectionCountBadge: some View {
        Text("\(selectedItems.count)")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }

    private func overflowButton(overflowItems: [FilterItem]) -> some View {
        Button {
            showOverflowPopover = true
        } label: {
            Text("+\(overflowItems.count)")
                .font(.caption)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showOverflowPopover, arrowEdge: .leading) {
            overflowPopoverContent(overflowItems: overflowItems)
        }
    }

    private func overflowPopoverContent(
        overflowItems: [FilterItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                loadingPlaceholder
            } else if isVersionSection {
                VersionGroupedView(
                    items: items,
                    selectedItems: $selectedItems
                ) { itemId in
                    toggleSelection(for: itemId)
                }
                .frame(maxHeight: CategorySectionConstants.popoverMaxHeight)
            } else {
                ScrollView {
                    FlowLayout {
                        ForEach(items) { item in
                            FilterChip(
                                title: item.name,
                                isSelected: selectedItems.contains(item.id)
                            ) { toggleSelection(for: item.id) }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: CategorySectionConstants.popoverMaxHeight)
            }
        }
        .frame(width: CategorySectionConstants.popoverWidth)
    }

    @ViewBuilder private var clearButton: some View {
        if !selectedItems.isEmpty {
            Button(action: clearSelection) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("filter.clear".localized())
        }
    }

    // MARK: - Content Views
    private var loadingPlaceholder: some View {
        ScrollView {
            FlowLayout {
                ForEach(
                    0..<CategorySectionConstants.placeholderCount,
                    id: \.self
                ) { _ in
                    FilterChip(
                        title: "common.loading".localized(),
                        isSelected: false
                    ) {}
                    .redacted(reason: .placeholder)
                }
            }
        }
        .frame(maxHeight: CategorySectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, CategorySectionConstants.verticalPadding)
    }

    private var contentWithOverflow: some View {
        let (visibleItems, _) = computeVisibleAndOverflowItems()
        return FlowLayout {
            ForEach(visibleItems) { item in
                FilterChip(
                    title: item.name,
                    isSelected: selectedItems.contains(item.id)
                ) { toggleSelection(for: item.id) }
            }
        }
        .frame(maxHeight: CategorySectionConstants.maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, CategorySectionConstants.verticalPadding)
    }

    // MARK: - Helper Methods
    private func computeVisibleAndOverflowItems() -> (
        [FilterItem], [FilterItem]
    ) {
        var rows: [[FilterItem]] = []
        var currentRow: [FilterItem] = []
        var currentRowWidth: CGFloat = 0

        for item in items {
            let estimatedWidth =
                CGFloat(item.name.count)
                * CategorySectionConstants.estimatedCharWidth
                + CategorySectionConstants.chipPadding

            if currentRowWidth + estimatedWidth > CategorySectionConstants.maxWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [item]
                currentRowWidth = estimatedWidth
            } else {
                currentRow.append(item)
                currentRowWidth += estimatedWidth
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        let visibleRows = rows.prefix(CategorySectionConstants.maxRows)
        let visibleItems = visibleRows.flatMap { $0 }
        let overflowItems = Array(items.dropFirst(visibleItems.count))

        return (visibleItems, overflowItems)
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
