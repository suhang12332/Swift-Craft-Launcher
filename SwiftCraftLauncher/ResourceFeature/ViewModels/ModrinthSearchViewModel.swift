import SwiftUI

// MARK: - ViewModel
/// Modrinth 搜索视图模型
@MainActor
final class ModrinthSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var results: [ModrinthProject] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var error: GlobalError?
    @Published private(set) var totalHits: Int = 0

    // MARK: - Private Properties
    var searchTask: Task<Void, Never>?
    var cacheTask: Task<Void, Never>?
    let pageSize: Int = 20
    let maxRetainedResults: Int = 60  // 最多保留 3 页（60 条）
    let settings = GeneralSettingsManager.shared
    let cacheNamespace = "resource_search_results"
    var activeSearchCacheKey: String?

    // MARK: - Initialization
    init() {}

    deinit {
        searchTask?.cancel()
        cacheTask?.cancel()
    }

    // MARK: - Public Methods
    // swiftlint:disable:next function_parameter_count
    func search(
        query: String,
        projectType: String,
        versions: [String],
        categories: [String],
        features: [String],
        resolutions: [String],
        performanceImpact: [String],
        loaders: [String],
        page: Int = 1,
        append: Bool = false,
        dataSource: DataSource = .modrinth
    ) async {
        // Cancel any existing search task
        searchTask?.cancel()
        let isFirstPage = !append && page == 1
        let cacheContext = SearchCacheContext(
            query: query,
            projectType: projectType,
            versions: versions,
            categories: categories,
            features: features,
            resolutions: resolutions,
            performanceImpact: performanceImpact,
            loaders: loaders,
            dataSource: dataSource,
        )
        let searchCacheKey = cacheKey(context: cacheContext)
        activeSearchCacheKey = searchCacheKey

        if isFirstPage, settings.enableResourcePageCache {
            cacheTask?.cancel()
            cacheTask = Task {
                guard let cached = await loadCachedFirstPageAsync(cacheKey: searchCacheKey) else {
                    return
                }
                guard !Task.isCancelled, activeSearchCacheKey == searchCacheKey else {
                    return
                }
                if results.isEmpty {
                    results = Array(cached.hits.prefix(maxRetainedResults))
                    totalHits = cached.totalHits
                    isLoading = false
                }
            }
        }

        searchTask = Task {
            do {
                if append {
                    isLoadingMore = true
                } else {
                    isLoading = results.isEmpty
                }
                error = nil

                // 检查任务是否被取消
                try Task.checkCancellation()

                let offset = (page - 1) * pageSize
                let filterOptions = FilterOptions(
                    resolutions: resolutions,
                    performanceImpact: performanceImpact,
                    loaders: loaders
                )
                let facets = buildFacets(
                    projectType: projectType,
                    versions: versions,
                    categories: categories,
                    features: features,
                    filterOptions: filterOptions
                )

                try Task.checkCancellation()

                let result: ModrinthResult
                if dataSource == .modrinth {
                    // 使用 Modrinth 服务
                    result = await ModrinthService.searchProjects(
                        facets: facets,
                        offset: offset,
                        limit: pageSize,
                        query: query
                    )
                } else {
                    // 使用 CurseForge 服务并转换为 Modrinth 格式
                    let cfParams = ModrinthToCurseForgeSearchAdapter.convertToSearchParams(
                        projectType: projectType,
                        versions: versions,
                        categories: categories,
                        resolutions: resolutions,
                        loaders: loaders,
                        query: query
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
                        pageSize: pageSize
                    )
                    result = CFToModrinthAdapter.convertSearchResult(cfResult)
                }

                try Task.checkCancellation()

                if !Task.isCancelled {
                    if append {
                        results.append(contentsOf: result.hits)
                        trimResultsIfNeeded()
                    } else {
                        results = Array(result.hits.prefix(maxRetainedResults))
                        if settings.enableResourcePageCache {
                            saveFirstPageCache(
                                cacheKey: searchCacheKey,
                                hits: result.hits,
                                totalHits: result.totalHits
                            )
                        }
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
                // 任务被取消，不需要处理
                return
            } catch {
                let globalError = GlobalError.from(error)
                if !Task.isCancelled {
                    self.error = globalError
                    self.isLoading = false
                    self.isLoadingMore = false
                }
                Logger.shared.error("搜索失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }
        }
    }

    func clearResults() {
        searchTask?.cancel()
        cacheTask?.cancel()
        results.removeAll()
        totalHits = 0
        error = nil
        isLoading = false
        isLoadingMore = false
    }

    @MainActor
    func beginNewSearch() {
        isLoading = true
        results.removeAll()
    }

    private func trimResultsIfNeeded() {
        if results.count > maxRetainedResults {
            results.removeFirst(results.count - maxRetainedResults)
        }
    }
}
