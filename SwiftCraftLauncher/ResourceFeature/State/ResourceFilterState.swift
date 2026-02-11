//
//  ResourceFilterState.swift
//  SwiftCraftLauncher
//
//  收拢资源筛选、分页、Tab、数据源、搜索与本地筛选等状态，通过 @EnvironmentObject 向下提供，减少 @Binding 透传。
//

import SwiftUI

/// 资源筛选与列表相关状态（可观测）
final class ResourceFilterState: ObservableObject {

    // MARK: - 筛选
    @Published var selectedVersions: [String] = []
    @Published var selectedLicenses: [String] = []
    @Published var selectedCategories: [String] = []
    @Published var selectedFeatures: [String] = []
    @Published var selectedResolutions: [String] = []
    @Published var selectedPerformanceImpact: [String] = []
    @Published var selectedLoaders: [String] = []
    @Published var sortIndex: String = AppConstants.modrinthIndex

    // MARK: - 分页与 Tab
    @Published var versionCurrentPage: Int = 1
    @Published var versionTotal: Int = 0
    @Published var selectedTab: Int = 0

    // MARK: - 数据源与搜索
    @Published var dataSource: DataSource
    @Published var searchText: String = ""
    @Published var localResourceFilter: LocalResourceFilter = .all

    init(dataSource: DataSource? = nil) {
        self.dataSource = dataSource ?? GameSettingsManager.shared.defaultAPISource
    }

    // MARK: - 便捷方法

    /// 清空所有筛选与分页（保留 dataSource / searchText 等按需可在此扩展）
    func clearFiltersAndPagination() {
        selectedVersions.removeAll()
        selectedLicenses.removeAll()
        selectedCategories.removeAll()
        selectedFeatures.removeAll()
        selectedResolutions.removeAll()
        selectedPerformanceImpact.removeAll()
        selectedLoaders.removeAll()
        sortIndex = AppConstants.modrinthIndex
        selectedTab = 0
        versionCurrentPage = 1
        versionTotal = 0
    }

    /// 仅清空搜索文本
    func clearSearchText() {
        searchText = ""
    }

    // MARK: - Bindings（供子视图需要 Binding 时使用）

    var selectedVersionsBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedVersions ?? [] }, set: { [weak self] in self?.selectedVersions = $0 })
    }
    var selectedLicensesBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedLicenses ?? [] }, set: { [weak self] in self?.selectedLicenses = $0 })
    }
    var selectedCategoriesBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedCategories ?? [] }, set: { [weak self] in self?.selectedCategories = $0 })
    }
    var selectedFeaturesBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedFeatures ?? [] }, set: { [weak self] in self?.selectedFeatures = $0 })
    }
    var selectedResolutionsBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedResolutions ?? [] }, set: { [weak self] in self?.selectedResolutions = $0 })
    }
    var selectedPerformanceImpactBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedPerformanceImpact ?? [] }, set: { [weak self] in self?.selectedPerformanceImpact = $0 })
    }
    var selectedLoadersBinding: Binding<[String]> {
        Binding(get: { [weak self] in self?.selectedLoaders ?? [] }, set: { [weak self] in self?.selectedLoaders = $0 })
    }
    var sortIndexBinding: Binding<String> {
        Binding(get: { [weak self] in self?.sortIndex ?? AppConstants.modrinthIndex }, set: { [weak self] in self?.sortIndex = $0 })
    }
    var versionCurrentPageBinding: Binding<Int> {
        Binding(get: { [weak self] in self?.versionCurrentPage ?? 1 }, set: { [weak self] in self?.versionCurrentPage = $0 })
    }
    var versionTotalBinding: Binding<Int> {
        Binding(get: { [weak self] in self?.versionTotal ?? 0 }, set: { [weak self] in self?.versionTotal = $0 })
    }
    var selectedTabBinding: Binding<Int> {
        Binding(get: { [weak self] in self?.selectedTab ?? 0 }, set: { [weak self] in self?.selectedTab = $0 })
    }
    var dataSourceBinding: Binding<DataSource> {
        Binding(get: { [weak self] in self?.dataSource ?? .modrinth }, set: { [weak self] in self?.dataSource = $0 })
    }
    var searchTextBinding: Binding<String> {
        Binding(get: { [weak self] in self?.searchText ?? "" }, set: { [weak self] in self?.searchText = $0 })
    }
    var localResourceFilterBinding: Binding<LocalResourceFilter> {
        Binding(get: { [weak self] in self?.localResourceFilter ?? .all }, set: { [weak self] in self?.localResourceFilter = $0 })
    }
}
