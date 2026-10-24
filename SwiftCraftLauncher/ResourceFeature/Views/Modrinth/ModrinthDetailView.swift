//
//  ModrinthDetailView.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Displays search results for Modrinth projects with filtering and pagination.
struct ModrinthDetailView: View {
    @Environment(DIContainer.self)
    private var container
    let query: String
    let selectedVersions: [String]
    let selectedCategories: [String]
    let selectedFeatures: [String]
    let selectedResolutions: [String]
    let selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    let selectedLoader: [String]
    let gameInfo: GameVersionInfo?
    @Binding var selectedItem: SidebarItem
    let gameType: Bool
    let header: AnyView?
    @Binding var scannedDetailIds: Set<String> // detail IDs from the parent for fast lookup
    let dataSource: DataSource

    @State private var viewModel = ModrinthSearchViewModel()
    @Binding var searchText: String
    @State private var coordinator = ModrinthDetailCoordinatorViewModel()
    @Environment(ResourceFilterState.self)
    private var filterState
    @Environment(FavoriteStore.self)
    private var favoriteStore

    init(
        query: String,
        selectedVersions: [String],
        selectedCategories: [String],
        selectedFeatures: [String],
        selectedResolutions: [String],
        selectedPerformanceImpact: [String],
        selectedProjectId: Binding<String?>,
        selectedLoader: [String],
        gameInfo: GameVersionInfo?,
        selectedItem: Binding<SidebarItem>,
        gameType: Bool,
        header: AnyView? = nil,
        scannedDetailIds: Binding<Set<String>> = .constant([]),
        dataSource: DataSource,
        searchText: Binding<String> = .constant(""),
    ) {
        self.query = query
        self.selectedVersions = selectedVersions
        self.selectedCategories = selectedCategories
        self.selectedFeatures = selectedFeatures
        self.selectedResolutions = selectedResolutions
        self.selectedPerformanceImpact = selectedPerformanceImpact
        _selectedProjectId = selectedProjectId
        self.selectedLoader = selectedLoader
        self.gameInfo = gameInfo
        _selectedItem = selectedItem
        self.gameType = gameType
        self.header = header
        _scannedDetailIds = scannedDetailIds
        self.dataSource = dataSource
        _searchText = searchText
    }

    var body: some View {
        List {
            if let header {
                header
                    .listRowSeparator(.hidden)
            }
            listContent
            if viewModel.isLoadingMore {
                loadingMoreIndicator
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .task {
            if gameType {
                await coordinator.initialLoadIfNeeded(
                    gameType: gameType,
                    searchViewModel: viewModel,
                    context: currentSearchContext,
                )
            }
        }
        // Re-trigger search when filter criteria change.
        .onChange(of: selectedVersions) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedCategories) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedFeatures) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedResolutions) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedPerformanceImpact) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: selectedLoader) { _, _ in
            coordinator.resetPagination()
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        .onChange(of: dataSource) { _, _ in
            viewModel.clearResults()
            coordinator.resetPagination()
            coordinator.hasLoaded = false
            coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
        }
        // Favorites-only mode searches by the stored favorite IDs, so toggling
        // the filter must run a new query instead of re-filtering loaded pages.
        .onChange(of: filterState.showFavoritesOnly) { _, _ in
            reloadSearchResults()
        }
        // Adding or removing a favorite while favorites-only mode is active
        // invalidates the current results. Drop them and re-query so unfavorited
        // projects are not retained in memory.
        .onChange(of: favoriteStore.favoriteIds) { oldValue, newValue in
            guard filterState.showFavoritesOnly,
                  oldValue[query] != newValue[query]
            else { return }
            reloadSearchResults()
        }
        .onChange(of: query) { _, _ in
            reloadSearchResults()
            searchText = ""
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "search.resources".localized(),
        )

        .onChange(of: searchText) { oldValue, newValue in
            if oldValue != newValue {
                coordinator.resetPagination()
                coordinator.debounceSearch(
                    searchViewModel: viewModel,
                    context: currentSearchContext,
                )
            }
        }
        .errorHandler(container.core.errorHandler)
        .onDisappear {
            cleanupOnDisappear()
        }
    }

    /// Clears the current results and searches again with the latest context.
    private func reloadSearchResults() {
        viewModel.clearResults()
        coordinator.cancelDebounce()
        coordinator.resetPagination()
        coordinator.triggerSearch(searchViewModel: viewModel, context: currentSearchContext)
    }

    private func cleanupOnDisappear() {
        coordinator.cancelDebounce()
        coordinator.resetPagination()
        coordinator.hasLoaded = false
        viewModel.clearResults()
    }

    @ViewBuilder private var listContent: some View {
        if viewModel.isLoading {
            ModrinthDetailListSkeletonRows()
        } else {
            ForEach(viewModel.results, id: \.projectId) { mod in
                ModrinthDetailCardView(
                    project: mod,
                    selectedVersions: selectedVersions,
                    selectedLoaders: selectedLoader,
                    gameInfo: gameInfo,
                    query: query,
                    type: true,
                    selectedItem: $selectedItem,
                    scannedDetailIds: scannedDetailIds,
                ) { hash in
                    scannedDetailIds.insert(hash)
                }
                .padding(.vertical, ModrinthConstants.UIConstants.verticalPadding)
                .listRowInsets(
                    EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8),
                )
                .listRowSeparator(.hidden)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedProjectId = mod.projectId
                    if let type = ResourceType(rawValue: query) {
                        selectedItem = .resource(type)
                    }
                }
                .onAppear {
                    coordinator.loadNextPageIfNeeded(
                        currentItem: mod,
                        searchViewModel: viewModel,
                        context: currentSearchContext,
                    )
                }
            }
        }
    }

    private var currentSearchContext: ModrinthSearchContext {
        ModrinthSearchContext(
            query: query,
            selectedVersions: selectedVersions,
            selectedCategories: selectedCategories,
            selectedFeatures: selectedFeatures,
            selectedResolutions: selectedResolutions,
            selectedPerformanceImpact: selectedPerformanceImpact,
            selectedLoader: selectedLoader,
            gameType: gameType,
            dataSource: dataSource,
            searchText: searchText,
            favoriteIds: filterState.showFavoritesOnly
                ? favoriteIdsForActiveDataSource
                : nil,
        )
    }

    /// Favorite IDs that belong to the active data source, sorted by project ID.
    ///
    /// Modrinth IDs are unprefixed; CurseForge IDs use the `cf-` prefix. Splitting
    /// them keeps provider-specific requests small and avoids sending irrelevant
    /// IDs to the other backend. The stable ID order keeps pagination consistent
    /// across repeated requests.
    private var favoriteIdsForActiveDataSource: [String] {
        let wantsCurseForge = filterState.dataSource == .curseforge
        return favoriteStore.favoriteIdsForType(query)
            .filter { $0.asProjectId.isCurseForge == wantsCurseForge }
            .sorted()
    }

    private var loadingMoreIndicator: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}
