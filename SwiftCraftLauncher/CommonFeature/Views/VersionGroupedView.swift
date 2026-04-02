import SwiftUI

// MARK: - Version Grouped View
/// 版本分组展示组件，用于按版本系列分组显示版本列表
struct VersionGroupedView: View {
    // MARK: - Properties
    let items: [FilterItem]
    @Binding var selectedItems: [String]
    let onItemTap: (String) -> Void
    var isMultiSelect: Bool = true  // 是否支持多选，默认为true

    // 单选模式的可选绑定
    @Binding var selectedItem: String?

    // MARK: - Initializers
    /// 多选模式初始化
    init(items: [FilterItem], selectedItems: Binding<[String]>, onItemTap: @escaping (String) -> Void) {
        self.items = items
        self._selectedItems = selectedItems
        self.onItemTap = onItemTap
        self.isMultiSelect = true
        self._selectedItem = .constant(nil)
    }

    /// 单选模式初始化
    init(items: [FilterItem], selectedItem: Binding<String?>, onItemTap: @escaping (String) -> Void) {
        self.items = items
        self._selectedItem = selectedItem
        self.onItemTap = onItemTap
        self.isMultiSelect = false
        self._selectedItems = .constant([])
    }

    // MARK: - Constants
    private enum Constants {
        static let groupSpacing: CGFloat = 8
        static let itemSpacing: CGFloat = 4
        static let groupTitlePadding: CGFloat = 4
    }

    // MARK: - Body
    var body: some View {
        let groups = groupVersions(items)
        let groupKeys = orderedVersionKeys(from: items)

        ScrollView {
            VStack(alignment: .leading, spacing: Constants.groupSpacing) {
                ForEach(groupKeys, id: \.self) { key in
                    versionGroupView(key: key, items: groups[key] ?? [])
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Private Views
    @ViewBuilder
    private func versionGroupView(key: String, items: [FilterItem]) -> some View {
        VStack(alignment: .leading, spacing: Constants.itemSpacing) {
            // 分组标题
            Text(key)
                .font(.headline.bold())
                .foregroundColor(.primary)
                .padding(.top, Constants.groupTitlePadding)

            // 版本项
            FlowLayout {
                ForEach(items) { item in
                    FilterChip(
                        title: item.name,
                        isSelected: isSelected(item.id)
                    ) {
                        onItemTap(item.id)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helper Methods
    /// 判断项目是否被选中
    private func isSelected(_ itemId: String) -> Bool {
        if isMultiSelect {
            return selectedItems.contains(itemId)
        } else {
            return selectedItem == itemId
        }
    }

    /// 将版本项按主版本号分组
    private func groupVersions(_ items: [FilterItem]) -> [String: [FilterItem]] {
        Dictionary(grouping: items) { item in
            versionGroupKey(for: item.name)
        }
    }

    /// 保持分组顺序与传入版本列表一致，不做额外排序。
    private func orderedVersionKeys(from items: [FilterItem]) -> [String] {
        var seen = Set<String>()
        return items.compactMap { item in
            let key = versionGroupKey(for: item.name)
            return seen.insert(key).inserted ? key : nil
        }
    }

    /// 兼容正式版、预发布版和快照版的分组键。
    /// 例如：
    /// - 1.21.1 -> 1.21
    /// - 1.21-pre1 -> 1.21
    /// - 24w14a -> 24w
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
