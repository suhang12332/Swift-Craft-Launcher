//
//  ModrinthDetailCoordinatorViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

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

    func paramsKey(page: Int) -> String {
        [
            query,
            selectedVersions.joined(separator: ","),
            selectedCategories.joined(separator: ","),
            selectedFeatures.joined(separator: ","),
            selectedResolutions.joined(separator: ","),
            selectedPerformanceImpact.joined(separator: ","),
            selectedLoader.joined(separator: ","),
            String(gameType),
            searchText,
            "page:\(page)",
            dataSource.rawValue,
        ].joined(separator: "|")
    }
}

/// Coordinates pagination, debounce, and error handling for Modrinth search.
@MainActor
final class ModrinthDetailCoordinatorViewModel: ObservableObject {
    @Published var error: GlobalError?
    @Published var hasLoaded: Bool = false

    private var currentPage: Int = 1
    private var lastSearchParams: String = ""
    private var debounceTask: Task<Void, Never>?
    private let errorHandler: GlobalErrorHandler

    init(errorHandler: GlobalErrorHandler = AppServices.errorHandler) {
        self.errorHandler = errorHandler
    }

    /// Whether more pages of results are available.
    var hasMoreResults: Bool {
        false
    }

    /// Resets pagination back to page one.
    func resetPagination() {
        currentPage = 1
        lastSearchParams = ""
    }

    /// Clears the current error.
    func clearError() {
        error = nil
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
            errorHandler.handle(globalError)
            self.error = globalError
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
            )
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
        )
    }

    private func preloadImages(searchViewModel: ModrinthSearchViewModel) {
        _ = searchViewModel.results
            .prefix(20)
            .compactMap(\.iconUrl)
            .compactMap(URL.init(string:))
    }
}
