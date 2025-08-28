import SwiftUI

// MARK: - Constants
private enum CategoryConstants {
    static let cacheTimeout: TimeInterval = 300
}

// MARK: - ViewModel
@MainActor
final class CategoryContentViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var categories: [Category] = []
    @Published private(set) var features: [Category] = []
    @Published private(set) var resolutions: [Category] = []
    @Published private(set) var performanceImpacts: [Category] = []
    @Published private(set) var versions: [GameVersion] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var error: GlobalError?
    @Published private(set) var loaders: [Loader] = []

    // MARK: - Private Properties
    private var lastFetchTime: Date?
    private let project: String
    private var loadTask: Task<Void, Never>?

    // MARK: - Initialization
    init(project: String) {
        self.project = project
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Public Methods
    func loadData() async {
        guard shouldFetchData else { return }

        loadTask?.cancel()
        loadTask = Task {
            await fetchData()
        }
    }

    func clearCache() {
        loadTask?.cancel()
        lastFetchTime = nil
        resetData()
    }

    func setError(_ error: GlobalError?) {
        self.error = error
    }

    // MARK: - Private Helpers
    private var shouldFetchData: Bool {
        guard let lastFetch = lastFetchTime else { return true }
        return Date().timeIntervalSince(lastFetch)
            >= CategoryConstants.cacheTimeout || categories.isEmpty
    }

    private func fetchData() async {
        isLoading = true
        error = nil

        do {
            async let categoriesTask = ModrinthService.fetchCategories()
            async let versionsTask = ModrinthService.fetchGameVersions()
            async let loadersTask = ModrinthService.fetchLoaders()
            let (categoriesResult, versionsResult, loadersResult) = await (
                categoriesTask, versionsTask, loadersTask
            )

            // 验证返回的数据
            guard !categoriesResult.isEmpty else {
                throw GlobalError.resource(
                    chineseMessage: "无法获取分类数据",
                    i18nKey: "error.resource.categories_not_found",
                    level: .notification
                )
            }

            guard !versionsResult.isEmpty else {
                throw GlobalError.resource(
                    chineseMessage: "无法获取游戏版本数据",
                    i18nKey: "error.resource.game_versions_not_found",
                    level: .notification
                )
            }

            await processFetchedData(
                categories: categoriesResult,
                versions: versionsResult,
                loaders: loadersResult
            )
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    private func processFetchedData(
        categories: [Category],
        versions: [GameVersion],
        loaders: [Loader]
    ) async {
        let projectType =
            project == ProjectType.datapack ? ProjectType.mod : project
        let filteredCategories = categories.filter {
            $0.project_type == projectType
        }

        await MainActor.run {
            self.versions = versions
            self.categories = filteredCategories.filter {
                $0.header == CategoryHeader.categories
            }
            self.features = filteredCategories.filter {
                $0.header == CategoryHeader.features
            }
            self.resolutions = filteredCategories.filter {
                $0.header == CategoryHeader.resolutions
            }
            self.performanceImpacts = filteredCategories.filter {
                $0.header == CategoryHeader.performanceImpact
            }
            self.lastFetchTime = Date()
            self.loaders = loaders
        }
    }

    private func handleError(_ error: Error) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("加载分类数据错误: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
        Task { @MainActor in
            self.error = globalError
        }
    }

    private func resetData() {
        categories.removeAll(keepingCapacity: false)
        features.removeAll(keepingCapacity: false)
        resolutions.removeAll(keepingCapacity: false)
        performanceImpacts.removeAll(keepingCapacity: false)
        versions.removeAll(keepingCapacity: false)
        loaders.removeAll(keepingCapacity: false)
        error = nil
        isLoading = false
    }
}
