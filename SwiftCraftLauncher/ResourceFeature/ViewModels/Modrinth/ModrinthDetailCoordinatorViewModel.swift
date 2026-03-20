import Foundation

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

@MainActor
final class ModrinthDetailCoordinatorViewModel: ObservableObject {
    @Published var error: GlobalError?
    @Published var hasLoaded: Bool = false

    private var currentPage: Int = 1
    private var lastSearchParams: String = ""
    private var debounceTask: Task<Void, Never>?

    var hasMoreResults: Bool {
        false
    }

    func resetPagination() {
        currentPage = 1
        lastSearchParams = ""
    }

    func clearError() {
        error = nil
    }

    func cancelDebounce() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    func initialLoadIfNeeded(
        gameType: Bool,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext
    ) async {
        guard gameType else { return }
        guard !hasLoaded else { return }
        hasLoaded = true
        resetPagination()
        await performSearchWithErrorHandling(
            searchViewModel: searchViewModel,
            context: context,
            page: 1,
            append: false
        )
    }

    func triggerSearch(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext
    ) {
        Task {
            await performSearchWithErrorHandling(
                searchViewModel: searchViewModel,
                context: context,
                page: 1,
                append: false
            )
        }
    }

    func debounceSearch(
        delaySeconds: Double = 0.5,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext
    ) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                return
            }
            await self.performSearchWithErrorHandling(
                searchViewModel: searchViewModel,
                context: context,
                page: 1,
                append: false
            )
        }
    }

    func loadNextPageIfNeeded(
        currentItem: ModrinthProject,
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext
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
                append: true
            )
        }
    }

    private func performSearchWithErrorHandling(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
        page: Int,
        append: Bool
    ) async {
        do {
            try await performSearchThrowing(
                searchViewModel: searchViewModel,
                context: context,
                page: page,
                append: append
            )
            preloadImages(searchViewModel: searchViewModel)
        } catch {
            let globalError = GlobalError.from(error)
            Logger.shared.error("搜索失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            self.error = globalError
        }
    }

    private func performSearchThrowing(
        searchViewModel: ModrinthSearchViewModel,
        context: ModrinthSearchContext,
        page: Int,
        append: Bool
    ) async throws {
        let params = context.paramsKey(page: page)
        if params == lastSearchParams {
            return
        }

        guard !context.query.isEmpty else {
            throw GlobalError.validation(
                chineseMessage: "查询类型不能为空",
                i18nKey: "error.validation.query_type_empty",
                level: .notification
            )
        }

        lastSearchParams = params
        if !append {
            searchViewModel.beginNewSearch()
        }

        await searchViewModel.search(
            query: context.searchText,
            projectType: context.query,
            versions: context.selectedVersions,
            categories: context.selectedCategories,
            features: context.selectedFeatures,
            resolutions: context.selectedResolutions,
            performanceImpact: context.selectedPerformanceImpact,
            loaders: context.selectedLoader,
            page: page,
            append: append,
            dataSource: context.dataSource
        )
    }

    private func preloadImages(searchViewModel: ModrinthSearchViewModel) {
        _ = searchViewModel.results
            .prefix(20)
            .compactMap { $0.iconUrl }
            .compactMap(URL.init(string:))
    }
}
