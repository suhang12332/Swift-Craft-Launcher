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
        let sortedKeys = sortVersionKeys(groups.keys)

        ScrollView {
            VStack(alignment: .leading, spacing: Constants.groupSpacing) {
                ForEach(sortedKeys, id: \.self) { key in
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
            let components = item.name.split(separator: ".")
            if components.count >= 2 {
                return "\(components[0]).\(components[1])"
            } else {
                return item.name
            }
        }
    }

    /// 对版本键进行排序（最新版本在前）
    private func sortVersionKeys(_ keys: Dictionary<String, [FilterItem]>.Keys) -> [String] {
        keys.sorted { key1, key2 in
            let components1 = key1.split(separator: ".").compactMap { Int($0) }
            let components2 = key2.split(separator: ".").compactMap { Int($0) }
            return components1.lexicographicallyPrecedes(components2)
        }
        .reversed()
    }
}
