//
//  VersionGroupedView.swift
//  CommonFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A view that displays versions grouped by major version series.
///
/// `LazyVStack` creates each group only when it scrolls into view, and every
/// group lays out its versions in a single pass.
struct VersionGroupedView: View {
    let items: [FilterItem]
    let selectedIds: Set<String>
    let onItemTap: (String) -> Void

    /// Initializes the view for multi-select mode.
    init(items: [FilterItem], selectedItems: [String], onItemTap: @escaping (String) -> Void) {
        self.items = items
        selectedIds = Set(selectedItems)
        self.onItemTap = onItemTap
    }

    /// Initializes the view for single-select mode.
    init(items: [FilterItem], selectedItem: String?, onItemTap: @escaping (String) -> Void) {
        self.items = items
        selectedIds = selectedItem.map { [$0] } ?? []
        self.onItemTap = onItemTap
    }

    private enum Constants {
        static let groupSpacing: CGFloat = 8
        static let itemSpacing: CGFloat = 4
        static let groupTitlePadding: CGFloat = 4
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Constants.groupSpacing) {
                ForEach(versionGroups) { group in
                    versionGroupView(group)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func versionGroupView(_ group: VersionGroup) -> some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            Text(group.key)
                .font(.headline.bold())
                .foregroundColor(.primary)
                .padding(.top, Constants.groupTitlePadding)

            FlowLayout {
                ForEach(group.items) { item in
                    FilterChip(
                        title: item.name,
                        isSelected: selectedIds.contains(item.id),
                    ) {
                        onItemTap(item.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Builds the ordered groups in a single pass over the items.
    private var versionGroups: [VersionGroup] {
        var groups: [VersionGroup] = []
        var indexByKey: [String: Int] = [:]

        for item in items {
            let key = versionGroupKey(for: item.name)
            if let index = indexByKey[key] {
                groups[index].items.append(item)
            } else {
                indexByKey[key] = groups.count
                groups.append(VersionGroup(key: key, items: [item]))
            }
        }

        return groups
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
            options: .regularExpression,
        ) else {
            return nil
        }

        return String(version[range])
    }

    private func extractSnapshotSeries(from version: String) -> String? {
        guard let range = version.range(
            of: #"^\d{2}w\d{2}[a-z]?"#,
            options: [.regularExpression, .caseInsensitive],
        ) else {
            return nil
        }

        let snapshot = String(version[range]).lowercased()
        return String(snapshot.prefix(5))
    }
}

/// A version group ordered by first appearance in the input list.
private struct VersionGroup: Identifiable {
    let key: String
    var items: [FilterItem]

    var id: String { key }
}
