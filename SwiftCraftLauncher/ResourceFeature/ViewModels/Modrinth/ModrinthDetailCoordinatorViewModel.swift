//
//  ModrinthDetailCoordinatorViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import Observation

/// Captures the search parameters used for a Modrinth search query.
struct ModrinthSearchContext: Equatable {
    let query: String
    let selectedVersions: [String]
    let selectedCategories: [String]
    let selectedFeatures: [String]
    let selectedResolutions: [String]
    let selectedPerformanceImpact: [String]
    let selectedLoader: [String]
    let gameType: Bool
    let dataSource: DataSource
    let searchText: String
    /// When non-nil, restricts the search to these favorite project IDs, sorted by ID.
    let favoriteIds: [String]?

    func paramsKey(page: Int) -> String {
        // Favorite changes explicitly reset pagination, so only the mode needs
        // to participate in the key; the full ID list would duplicate state.
        let favoritesKey = favoriteIds == nil ? "favorites:off" : "favorites:on"

        return [
            query,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(gameType),
            searchText,
            favoritesKey,
            "page:\(page)",
            dataSource.rawValue,
        ].joined(separator: "|")
    }
}

/// Coordinates pagination, debounce, and error handling for Modrinth search.
@MainActor
@Observable
final class ModrinthDetailCoordinatorViewModel {
    var hasLoaded: Bool = false

    private var currentPage: Int = 1
    private var lastSearchParams: String = ""
    private var debounceTask: Task<Void, Never>?

    init() { }

    /// Resets pagination back to page one.
    func resetPagination() {
        currentPage = 1
        lastSearchParams = ""
    }

    /// Cancels any pending debounced search.
    func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    /// Performs the initial search on first load if game type is enabled.
    func initialLoadIfNeeded(
        gameType: Bool,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
    ) async {
        guard gameType else { return }
        guard !hasLoaded else { return }
        hasLoaded = true
        resetPagination()
        await performSearchWithErrorHandling(
            searchViewModel: searchViewModel,
            context: context,
            page: 1,
            append: false,
        )
    }

    /// Triggers an immediate search with the given context.
    func triggerSearch(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
    ) {
        Task {
            await performSearchWithErrorHandling(
                searchViewModel: searchViewModel,
                context: context,
                page: 1,
                append: false,
            )
        }
    }

    /// Triggers a search after the specified delay, canceling any previous pending search.
    /// - Parameters:
    ///   - delaySeconds: The delay before triggering the search.
    ///   - searchViewModel: The search view model.
    ///   - context: The search context.
    func debounceSearch(
        delaySeconds: Double = 0.5,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
    ) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                return
            }
            await performSearchWithErrorHandling(
                searchViewModel: searchViewModel,
                context: context,
                page: 1,
                append: false,
            )
        }
    }

    /// Loads the next page of results if the current item is near the end of the list.
    /// - Parameters:
    ///   - currentItem: The current project item triggering the pagination check.
    ///   - searchViewModel: The search view model.
    ///   - context: The search context.
    func loadNextPageIfNeeded(
        currentItem: ModrinthProject,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
    ) {
        guard searchViewModel.results.count < searchViewModel.totalHits,
              !searchViewModel.isLoading,
              !searchViewModel.isLoadingMore
        else { return }

        guard let index = searchViewModel.results.firstIndex(where: { $0.projectId == currentItem.projectId }) else {
            return
        }

        let thresholdIndex = max(searchViewModel.results.count - 5, 0)
        guard index >= thresholdIndex else { return }

        currentPage += 1
        let nextPage = currentPage
        Task {
            await performSearchWithErrorHandling(
                searchViewModel: searchViewModel,
                context: context,
                page: nextPage,
                append: true,
            )
        }
    }

    private func performSearchWithErrorHandling(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
        page: Int,
        append: Bool,
    ) async {
        do {
            try await performSearchThrowing(
                searchViewModel: searchViewModel,
                context: context,
                page: page,
                append: append,
            )
            preloadImages(searchViewModel: searchViewModel)
        } catch {
            let globalError = GlobalError.from(error)
            AppLog.resource.error("Search failed: \(globalError.localizedDescription)")
            DIContainer.shared.core.errorHandler.handle(globalError)
        }
    }

    private func performSearchThrowing(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
        page: Int,
        append: Bool,
    ) async throws {
        let params = context.paramsKey(page: page)
        if params == lastSearchParams {
            return
        }

        guard !context.query.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.query_type_empty",
                level: .notification,
                message: "context.query is empty, searchText='\(context.searchText)'",
            )
        }

        // Favorites-only mode with no favorites resolves to an empty list
        // locally. Skip the search (and its loading state) so the list does not
        // flash placeholder rows before it goes empty.
        if let favoriteIds = context.favoriteIds, favoriteIds.isEmpty {
            searchViewModel.clearResults()
            return
        }

        lastSearchParams = params
        if !append {
            searchViewModel.beginNewSearch()
        }

        await searchViewModel.search(
            query: context.searchText,
            projectType: context.query,
            filterOptions: FilterOptions(
                versions: context.selectedVersions,
                categories: context.selectedCategories,
                features: context.selectedFeatures,
                resolutions: context.selectedResolutions,
                performanceImpact: context.selectedPerformanceImpact,
                loaders: context.selectedLoader,
            ),
            page: page,
            append: append,
            dataSource: context.dataSource,
            favoriteIds: context.favoriteIds,
        )
    }

    private func preloadImages(searchViewModel: ModrinthSearchViewModel) {
        _ = searchViewModel.results
            .prefix(20)
            .compactMap(\.iconUrl)
            .compactMap(URL.init(string:))
    }
}
