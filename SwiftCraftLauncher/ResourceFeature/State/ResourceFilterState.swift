//
//  ResourceFilterState.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Observation

/// Aggregates resource filter, pagination, tab, data source, search, and local filter state.
///
/// Intended to be provided via `@Environment` to reduce `@Binding` proliferation.
@MainActor
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
}
