//
//  ModrinthSearchViewModel.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Manages Modrinth project search state and pagination.
@MainActor
final class ModrinthSearchViewModel: ObservableObject {
    @Published private(set) var results: [ModrinthProject] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var error: GlobalError?
    @Published private(set) var totalHits: Int = 0

    var searchTask: Task<Void, Never>?
    let pageSize: Int = 20

    init() { }

    deinit {
        searchTask?.cancel()
    }

    /// Searches for projects with the given query and filters.
    ///
    /// Cancels any previous search before starting a new one. Supports
    /// both Modrinth and CurseForge data sources via the adapter layer.
    /// - Parameters:
    ///   - query: The search query string.
    ///   - projectType: The type of project to search for.
    ///   - filterOptions: The filters to apply to the search.
    ///   - page: The page of results to fetch.
    ///   - append: Whether to append results to the existing list.
    ///   - dataSource: The search backend to use.
    func search(
        query: String,
        projectType: String,
        filterOptions: FilterOptions,
        page: Int = 1,
        append: Bool = false,
        dataSource: DataSource = .modrinth,
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
                let facets = buildFacets(
                    projectType: projectType,
                    filterOptions: filterOptions,
                )

                try Task.checkCancellation()

                let result: ModrinthResult
                if dataSource == .modrinth {
                    result = await ModrinthService.searchProjects(
                        facets: facets,
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
                    let cfResult = await CurseForgeService.searchProjects(
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
                    totalHits = result.totalHits
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

    /// Cancels any ongoing search and clears all results.
    func clearResults() {
        searchTask?.cancel()
        results.removeAll()
        totalHits = 0
        error = nil
        isLoading = false
        isLoadingMore = false
    }

    /// Prepares the view model for a new search by resetting state.
    @MainActor
    func beginNewSearch() {
        isLoading = true
        results.removeAll()
    }
}
