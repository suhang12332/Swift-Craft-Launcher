//
//  ModrinthSearchViewModel+Favorites.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation

/// Provides favorites-only search support for both data sources.
///
/// Favorite IDs are read from the local favorites database one page at a time
/// and sent to the provider as a single batch, so a request never carries the
/// whole collection. Provider filters are applied per database page; IDs that
/// do not match are skipped by scanning further pages until the result page is
/// full or the database is exhausted.
extension ModrinthSearchViewModel {
    /// Fetches the given favorited projects that match the active filters.
    /// - Parameters:
    ///   - favoriteIds: Favorite project IDs to resolve (one page at a time).
    ///   - projectType: The resource type being displayed.
    ///   - filterOptions: The active filter selections.
    ///   - query: The current search text.
    ///   - dataSource: The provider to query.
    /// - Returns: Matching favorites ordered by project ID.
    func favoriteProjects(
        favoriteIds: [String],
        projectType: String,
        filterOptions: FilterOptions,
        query: String,
        dataSource: DataSource,
    ) async throws -> [ModrinthProject] {
        guard !favoriteIds.isEmpty else { return [] }

        switch dataSource {
        case .modrinth:
            return try await fetchModrinthFavoriteProjects(
                favoriteIds: favoriteIds,
                projectType: projectType,
                filterOptions: filterOptions,
                query: query,
            )
        case .curseforge:
            return try await fetchCurseForgeFavoriteProjects(
                favoriteIds: favoriteIds,
                projectType: projectType,
                filterOptions: filterOptions,
                query: query,
            )
        }
    }

    /// Fetches the favorited Modrinth projects for one ID page.
    private func fetchModrinthFavoriteProjects(
        favoriteIds: [String],
        projectType: String,
        filterOptions: FilterOptions,
        query: String,
    ) async throws -> [ModrinthProject] {
        try Task.checkCancellation()

        let facets = buildFacets(
            projectType: projectType,
            filterOptions: filterOptions,
            favoriteIds: favoriteIds,
        )
        let result = try await ModrinthService.searchProjectsThrowing(
            facets: facets,
            index: AppConstants.modrinthIndex,
            offset: 0,
            limit: SearchPagination.pageSize,
            query: query,
        )

        return sortedByProjectId(result.hits)
    }

    /// Fetches the favorited CurseForge projects for one ID page and filters them locally.
    private func fetchCurseForgeFavoriteProjects(
        favoriteIds: [String],
        projectType: String,
        filterOptions: FilterOptions,
        query: String,
    ) async throws -> [ModrinthProject] {
        let modIds = favoriteIds.compactMap { id -> Int? in
            let identifier = id.asProjectId
            guard identifier.isCurseForge else { return nil }
            return try? identifier.parseCurseForgeId().modId
        }

        guard !modIds.isEmpty else { return [] }

        let params = ModrinthToCurseForgeSearchAdapter.convertToSearchParams(
            projectType: projectType,
            versions: filterOptions.versions,
            categories: filterOptions.categories,
            resolutions: filterOptions.resolutions,
            loaders: filterOptions.loaders,
            query: query,
        )

        try Task.checkCancellation()
        let mods = try await CurseForgeService.fetchModsByIdsThrowing(ids: modIds)

        var seenModIds = Set<Int>()
        let matchingMods = mods.filter {
            seenModIds.insert($0.id).inserted && matches($0, params: params)
        }
        let hits = CFToModrinthAdapter.convertSearchResult(
            CurseForgeSearchResult(data: matchingMods, pagination: nil),
        ).hits

        return sortedByProjectId(hits)
    }

    /// Sorts projects by ID so pagination stays stable across repeated requests.
    private func sortedByProjectId(_ projects: [ModrinthProject]) -> [ModrinthProject] {
        projects.sorted { $0.projectId < $1.projectId }
    }

    /// Whether a CurseForge project satisfies the converted search parameters.
    private func matches(
        _ mod: CurseForgeMod,
        params: ModrinthToCurseForgeSearchAdapter.SearchParams,
    ) -> Bool {
        if let classId = params.classId, mod.classId != classId {
            return false
        }

        if let searchFilter = params.searchFilter, !searchFilter.isEmpty {
            let searchableText = ([mod.name, mod.summary] + (mod.authors ?? []).map(\.name))
                .joined(separator: " ")
            let tokens = searchFilter.split(whereSeparator: \.isWhitespace)
            if !tokens.allSatisfy({ searchableText.localizedCaseInsensitiveContains($0) }) {
                return false
            }
        }

        if let gameVersions = params.gameVersions, !gameVersions.isEmpty {
            let modVersions = Set((mod.latestFilesIndexes ?? []).map(\.gameVersion))
            if modVersions.isDisjoint(with: gameVersions) {
                return false
            }
        }

        if let categoryIds = params.categoryIds, !categoryIds.isEmpty {
            let modCategoryIds = Set((mod.categories ?? []).map(\.id))
            if modCategoryIds.isDisjoint(with: categoryIds) {
                return false
            }
        }

        if let modLoaderTypes = params.modLoaderTypes, !modLoaderTypes.isEmpty {
            let modLoaders = Set((mod.latestFilesIndexes ?? []).compactMap(\.modLoader))
            if modLoaders.isDisjoint(with: modLoaderTypes) {
                return false
            }
        }

        return true
    }
}
