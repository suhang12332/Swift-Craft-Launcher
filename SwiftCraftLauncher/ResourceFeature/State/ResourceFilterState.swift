//
//  ResourceFilterState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Aggregates resource filter, pagination, tab, data source, search, and local filter state.
///
/// Intended to be provided via `@EnvironmentObject` to reduce `@Binding` proliferation.
final class ResourceFilterState: ObservableObject {
    @Published var selectedVersions: [String] = []
    @Published var selectedLicenses: [String] = []
    @Published var selectedCategories: [String] = []
    @Published var selectedFeatures: [String] = []
    @Published var selectedResolutions: [String] = []
    @Published var selectedPerformanceImpact: [String] = []
    @Published var selectedLoaders: [String] = []
    @Published var sortIndex: String = AppConstants.modrinthIndex

    @Published var versionCurrentPage: Int = 1
    @Published var versionTotal: Int = 0
    @Published var selectedTab: Int = 0

    @Published var dataSource: DataSource
    @Published var searchText: String = ""
    @Published var localResourceFilter: LocalResourceFilter = .all

    init(
        dataSource: DataSource? = nil,
        gameSettingsManager: GameSettingsManager = AppServices.gameSettingsManager,
    ) {
        self.dataSource = dataSource ?? gameSettingsManager.defaultAPISource
    }

    /// Clears all filter selections and resets pagination.
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

    /// Clears the search text only.
    func clearSearchText() {
        searchText = ""
    }

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
