//
//  ModrinthSearchViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Manages Modrinth project search state and pagination.
@MainActor
@Observable
final class ModrinthSearchViewModel {
    private(set) var results: [ModrinthProject] = []
    private(set) var isLoading: Bool = false
    private(set) var isLoadingMore: Bool = false
    private(set) var error: GlobalError?
    /// Whether another page of results can be loaded.
    private(set) var hasMoreResults: Bool = false

    var searchTask: Task<Void, Never>?
    let pageSize: Int = SearchPagination.pageSize

    /// Keyset cursor for favorites-only pagination: the last favorite ID that
    /// has been scanned. `nil` means the next request starts from the beginning.
    private var favoriteCursor: String?

    init() { }

    /// Searches for projects with the given query and filters.
    ///
    /// Cancels any previous search before starting a new one. Supports
    /// both Modrinth and CurseForge data sources via the adapter layer.
    /// - Parameters:
    ///   - query: The search query string.
    ///   - projectType: The type of project to search for.
    ///   - filterOptions: The filters to apply to the search.
    ///   - page: The page of results to fetch. Ignored for favorites, which
    ///     advance through the local database with a keyset cursor.
    ///   - append: Whether to append results to the existing list.
    ///   - dataSource: The search backend to use.
    ///   - favoritesOnly: When `true`, searches the favorite projects stored in
    ///     the local database. IDs are paged with a keyset cursor, so only the
    ///     current page's project details are fetched from the provider.
    func search(
        query: String,
        projectType: String,
        filterOptions: FilterOptions,
        page: Int = 1,
        append: Bool = false,
        dataSource: DataSource = .modrinth,
        favoritesOnly: Bool = false,
    ) async {
        searchTask?.cancel()

        searchTask = Task {
            do {
                if append {
                    isLoadingMore = true
                } else {
                    isLoading = true
                }
                error = nil

                try Task.checkCancellation()

                let offset = (page - 1) * pageSize

                try Task.checkCancellation()

                let result: ModrinthResult
                var favoriteHasMore = false
                var favoriteNextCursor: String?
                if favoritesOnly {
                    let favoritePage = try await loadFavoritePage(
                        projectType: projectType,
                        filterOptions: filterOptions,
                        query: query,
                        dataSource: dataSource,
                        append: append,
                    )
                    favoriteHasMore = favoritePage.hasMore
                    favoriteNextCursor = favoritePage.nextCursor
                    result = ModrinthResult(
                        hits: favoritePage.hits,
                        offset: 0,
                        limit: pageSize,
                        totalHits: favoritePage.hits.count,
                    )
                } else if dataSource == .modrinth {
                    let facets = buildFacets(
                        projectType: projectType,
                        filterOptions: filterOptions,
                    )
                    result = try await ModrinthService.searchProjectsThrowing(
                        facets: facets,
                        index: AppConstants.modrinthIndex,
                        offset: offset,
                        limit: pageSize,
                        query: query,
                    )
                } else {
                    let cfParams = ModrinthToCurseForgeSearchAdapter.convertToSearchParams(
                        projectType: projectType,
                        versions: filterOptions.versions,
                        categories: filterOptions.categories,
                        resolutions: filterOptions.resolutions,
                        loaders: filterOptions.loaders,
                        query: query,
                    )
                    let cfResult = try await CurseForgeService.searchProjectsThrowing(
                        gameId: 432, // Minecraft
                        classId: cfParams.classId,
                        categoryId: nil,
                        categoryIds: cfParams.categoryIds,
                        gameVersion: nil,
                        gameVersions: cfParams.gameVersions,
                        searchFilter: cfParams.searchFilter,
                        modLoaderType: nil,
                        modLoaderTypes: cfParams.modLoaderTypes,
                        index: offset,
                        pageSize: pageSize,
                    )
                    result = CFToModrinthAdapter.convertSearchResult(cfResult)
                }

                try Task.checkCancellation()

                if !Task.isCancelled {
                    if append {
                        results.append(contentsOf: result.hits)
                    } else {
                        results = result.hits
                    }
                    if favoritesOnly {
                        favoriteCursor = favoriteNextCursor
                        hasMoreResults = favoriteHasMore
                    } else {
                        hasMoreResults = results.count < result.totalHits
                    }
                }

                try Task.checkCancellation()

                if !Task.isCancelled {
                    if append {
                        isLoadingMore = false
                    } else {
                        isLoading = false
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                let globalError = GlobalError.from(error)
                if !Task.isCancelled {
                    self.error = globalError
                    self.isLoading = false
                    self.isLoadingMore = false
                }
                AppLog.resource.error("Search failed: \(globalError.localizedDescription)")
                DIContainer.shared.core.errorHandler.handle(globalError)
            }
        }
    }

    /// Loads one page of favorites from the local database.
    ///
    /// Favorite IDs are paged with a keyset cursor so only the current page's
    /// projects are fetched from the provider. Filters are applied by the
    /// provider, so IDs that do not match are skipped by scanning further
    /// database pages until the page is full or no IDs remain.
    private func loadFavoritePage(
        projectType: String,
        filterOptions: FilterOptions,
        query: String,
        dataSource: DataSource,
        append: Bool,
    ) async throws -> (hits: [ModrinthProject], hasMore: Bool, nextCursor: String?) {
        let store = DIContainer.shared.core.favoriteStore
        var cursor = append ? favoriteCursor : nil

        var hits: [ModrinthProject] = []
        var hasMore = false

        while hits.count < pageSize {
            try Task.checkCancellation()

            let remaining = pageSize - hits.count
            let ids = store.favoriteIdsPage(
                type: projectType,
                dataSource: dataSource,
                after: cursor,
                limit: remaining,
            )
            guard !ids.isEmpty else {
                hasMore = false
                break
            }

            let projects = try await favoriteProjects(
                favoriteIds: ids,
                projectType: projectType,
                filterOptions: filterOptions,
                query: query,
                dataSource: dataSource,
            )
            hits.append(contentsOf: projects)
            cursor = ids.last

            hasMore = !store.favoriteIdsPage(
                type: projectType,
                dataSource: dataSource,
                after: cursor,
                limit: 1,
            ).isEmpty
            if !hasMore {
                break
            }
        }

        return (hits, hasMore, cursor)
    }

    /// Cancels any ongoing search and clears all results.
    func clearResults() {
        searchTask?.cancel()
        results.removeAll()
        error = nil
        isLoading = false
        isLoadingMore = false
        hasMoreResults = false
        favoriteCursor = nil
    }

    /// Removes the given projects from the currently displayed results without
    /// issuing a new search.
    func removeProjects(withIds ids: Set<String>) {
        guard !ids.isEmpty else { return }
        results.removeAll { ids.contains($0.projectId) }
    }

    /// Prepares the view model for a new search by resetting state.
    @MainActor
    func beginNewSearch() {
        clearResults()
        isLoading = true
    }
}
