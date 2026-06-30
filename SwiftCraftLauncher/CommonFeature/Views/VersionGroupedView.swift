//
//  VersionGroupedView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view that displays versions grouped by major version series.
struct VersionGroupedView: View {
    let items: [FilterItem]
    @Binding var selectedItems: [String]
    let onItemTap: (String) -> Void
    var isMultiSelect: Bool = true
    @State private var visibleItemCounts: [String: Int] = [:]
    @State private var visibleGroupCount: Int = Constants.initialVisibleGroupCount

    @Binding var selectedItem: String?

    /// Initializes the view for multi-select mode.
    init(items: [FilterItem], selectedItems: Binding<[String]>, onItemTap: @escaping (String) -> Void) {
        self.items = items
        self._selectedItems = selectedItems
        self.onItemTap = onItemTap
        self.isMultiSelect = true
        self._selectedItem = .constant(nil)
    }

    /// Initializes the view for single-select mode.
    init(items: [FilterItem], selectedItem: Binding<String?>, onItemTap: @escaping (String) -> Void) {
        self.items = items
        self._selectedItem = selectedItem
        self.onItemTap = onItemTap
        self.isMultiSelect = false
        self._selectedItems = .constant([])
    }

    private enum Constants {
        static let groupSpacing: CGFloat = 8
        static let itemSpacing: CGFloat = 4
        static let groupTitlePadding: CGFloat = 4
        static let initialVisibleGroupCount = 6
        static let incrementalGroupLoadBatchSize = 4
        static let initialVisibleItemsPerGroup = 12
        static let incrementalLoadBatchSize = 12
    }

    var body: some View {
        let groups = groupVersions(items)
        let groupKeys = orderedVersionKeys(from: items)
        let visibleGroupKeys = Array(groupKeys.prefix(visibleGroupCount))

        ScrollView {
            LazyVStack(alignment: .leading, spacing: Constants.groupSpacing) {
                ForEach(visibleGroupKeys, id: \.self) { key in
                    versionGroupView(key: key, items: groups[key] ?? [])
                        .onAppear {
                            loadMoreGroupsIfNeeded(currentKey: key, groupKeys: groupKeys)
                        }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func versionGroupView(key: String, items: [FilterItem]) -> some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            Text(key)
                .font(.headline.bold())
                .foregroundColor(.primary)
                .padding(.top, Constants.groupTitlePadding)

            FlowLayout {
                ForEach(visibleItems(for: key, items: items)) { item in
                    FilterChip(
                        title: item.name,
                        isSelected: isSelected(item.id)
                    ) {
                        onItemTap(item.id)
                    }
                    .onAppear {
                        loadMoreItemsIfNeeded(currentItem: item, in: key, allItems: items)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func isSelected(_ itemId: String) -> Bool {
        if isMultiSelect {
            return selectedItems.contains(itemId)
        } else {
            return selectedItem == itemId
        }
    }

    private func visibleItems(for key: String, items: [FilterItem]) -> [FilterItem] {
        let visibleCount = visibleItemCounts[key, default: Constants.initialVisibleItemsPerGroup]
        return Array(items.prefix(visibleCount))
    }

    private func loadMoreGroupsIfNeeded(currentKey: String, groupKeys: [String]) {
        guard currentKey == groupKeys.prefix(visibleGroupCount).last else {
            return
        }

        guard visibleGroupCount < groupKeys.count else { return }

        visibleGroupCount = min(
            visibleGroupCount + Constants.incrementalGroupLoadBatchSize,
            groupKeys.count
        )
    }

    private func loadMoreItemsIfNeeded(currentItem: FilterItem, in key: String, allItems: [FilterItem]) {
        guard currentItem.id == visibleItems(for: key, items: allItems).last?.id else {
            return
        }

        let currentVisibleCount = visibleItemCounts[key, default: Constants.initialVisibleItemsPerGroup]
        guard currentVisibleCount < allItems.count else { return }

        visibleItemCounts[key] = min(
            currentVisibleCount + Constants.incrementalLoadBatchSize,
            allItems.count
        )
    }

    private func groupVersions(_ items: [FilterItem]) -> [String: [FilterItem]] {
        Dictionary(grouping: items) { item in
            versionGroupKey(for: item.name)
        }
    }

    private func orderedVersionKeys(from items: [FilterItem]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            let key = versionGroupKey(for: item.name)
            return seen.insert(key).inserted ? key : nil
        }
    }

    private func versionGroupKey(for version: String) -> String {
        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)

        if let releaseSeries = extractReleaseSeries(from: trimmedVersion) {
            return releaseSeries
        }

        if let snapshotSeries = extractSnapshotSeries(from: trimmedVersion) {
            return snapshotSeries
        }

        return trimmedVersion
    }

    private func extractReleaseSeries(from version: String) -> String? {
        guard let range = version.range(
            of: #"^\d+\.\d+"#,
            options: .regularExpression
        ) else {
            return nil
        }

        return String(version[range])
    }

    private func extractSnapshotSeries(from version: String) -> String? {
        guard let range = version.range(
            of: #"^\d{2}w\d{2}[a-z]?"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        let snapshot = String(version[range]).lowercased()
        return String(snapshot.prefix(3))
    }
}
