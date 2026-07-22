//
//  ResourceFilterState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation
import SwiftUI

/// Aggregates resource filter, pagination, tab, data source, search, and local filter state.
///
/// Intended to be provided via `@Environment` to reduce `@Binding` proliferation.
@Observable
final class ResourceFilterState {
    var selectedVersions: [String] = []
    var selectedLicenses: [String] = []
    var selectedCategories: [String] = []
    var selectedFeatures: [String] = []
    var selectedResolutions: [String] = []
    var selectedPerformanceImpact: [String] = []
    var selectedLoaders: [String] = []
    var sortIndex: String = AppConstants.modrinthIndex

    var versionCurrentPage: Int = 1
    var versionTotal: Int = 0
    var selectedTab: Int = 0

    var dataSource: DataSource
    var searchText: String = ""
    var localResourceFilter: LocalResourceFilter = .all
    var showFavoritesOnly: Bool = false

    init(
        dataSource: DataSource? = nil,
        gameSettingsManager: GameSettingsManager = DIContainer.shared.ui.gameSettingsManager,
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

    private func bind<V>(_ keyPath: WritableKeyPath<ResourceFilterState, V>, fallback: V) -> Binding<V> {
        Binding(
            get: { [weak self] in self?[keyPath: keyPath] ?? fallback },
            set: { [weak self] in self?[keyPath: keyPath] = $0 },
        )
    }

    var selectedVersionsBinding: Binding<[String]> { bind(\.selectedVersions, fallback: []) }
    var selectedLicensesBinding: Binding<[String]> { bind(\.selectedLicenses, fallback: []) }
    var selectedCategoriesBinding: Binding<[String]> { bind(\.selectedCategories, fallback: []) }
    var selectedFeaturesBinding: Binding<[String]> { bind(\.selectedFeatures, fallback: []) }
    var selectedResolutionsBinding: Binding<[String]> { bind(\.selectedResolutions, fallback: []) }
    var selectedPerformanceImpactBinding: Binding<[String]> { bind(\.selectedPerformanceImpact, fallback: []) }
    var selectedLoadersBinding: Binding<[String]> { bind(\.selectedLoaders, fallback: []) }
    var sortIndexBinding: Binding<String> { bind(\.sortIndex, fallback: AppConstants.modrinthIndex) }
    var versionCurrentPageBinding: Binding<Int> { bind(\.versionCurrentPage, fallback: 1) }
    var versionTotalBinding: Binding<Int> { bind(\.versionTotal, fallback: 0) }
    var selectedTabBinding: Binding<Int> { bind(\.selectedTab, fallback: 0) }
    var dataSourceBinding: Binding<DataSource> { bind(\.dataSource, fallback: .modrinth) }
    var searchTextBinding: Binding<String> { bind(\.searchText, fallback: "") }
    var localResourceFilterBinding: Binding<LocalResourceFilter> { bind(\.localResourceFilter, fallback: .all) }
    var showFavoritesOnlyBinding: Binding<Bool> { bind(\.showFavoritesOnly, fallback: false) }
}
