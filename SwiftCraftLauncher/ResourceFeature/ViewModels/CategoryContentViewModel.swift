import SwiftUI

// MARK: - ViewModel
@MainActor
final class CategoryContentViewModel: ObservableObject {
    private struct CategoryContentCachePayload: Codable {
        let categories: [Category]
        let features: [Category]
        let resolutions: [Category]
        let performanceImpacts: [Category]
        let versions: [GameVersion]
        let loaders: [Loader]
        let plays: [Category]
        let metas: [Category]
        let serverFeatures: [Category]
        let communitys: [Category]
        let updatedAt: Date
    }

    // MARK: - Published Properties
    @Published private(set) var categories: [Category] = []
    @Published private(set) var features: [Category] = []
    @Published private(set) var resolutions: [Category] = []
    @Published private(set) var performanceImpacts: [Category] = []
    @Published private(set) var versions: [GameVersion] = []
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var error: GlobalError?
    @Published private(set) var loaders: [Loader] = []
    @Published private(set) var plays: [Category] = []
    @Published private(set) var metas: [Category] = []
    @Published private(set) var serverFeatures: [Category] = []
    @Published private(set) var communitys: [Category] = []

    // MARK: - Private Properties
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
        loadTask?.cancel()
        loadTask = nil
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchData()
        }
    }

    func clearCache() {
        loadTask?.cancel()
        loadTask = nil
        resetData()
    }

    func setError(_ error: GlobalError?) {
        self.error = error
    }

    private func fetchData() async {
        isLoading = true
        error = nil

        do {
            async let categoriesTask = ModrinthService.fetchCategories()
            async let versionsTask = ModrinthService.fetchGameVersions()

            // 光影（shader）的加载器从 API 获取，其他项目类型使用静态列表
            let loadersTask: Task<[Loader], Never>
            if project == ProjectType.shader {
                // 光影：从 API 获取加载器
                loadersTask = Task {
                    await ModrinthService.fetchLoaders()
                }
            } else {
                // 其他项目类型：使用静态加载器列表
                loadersTask = Task {
                    Self.getStaticLoaders()
                }
            }

            let (categoriesResult, versionsResult, loadersResult) = await (
                categoriesTask, versionsTask, loadersTask.value
            )

            try Task.checkCancellation()

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
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            handleError(error)
        }

        isLoading = false
    }

    /// 获取静态加载器列表（不调用 API）
    /// - Returns: 四个主要加载器：fabric、forge、quilt、neoforge
    private static func getStaticLoaders() -> [Loader] {
        return [
            Loader(
                name: GameLoader.fabric.displayName,
                icon: GameLoader.fabric.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue]
            ),
            Loader(
                name: GameLoader.forge.displayName,
                icon: GameLoader.forge.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue]
            ),
            Loader(
                name: GameLoader.quilt.rawValue,
                icon: GameLoader.quilt.rawValue,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue]
            ),
            Loader(
                name: GameLoader.neoforge.displayName,
                icon: GameLoader.neoforge.displayName,
                supported_project_types: [ResourceType.mod.rawValue, ResourceType.modpack.rawValue]
            ),
        ]
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
            self.versions = versions.filter { CommonUtil.isVersionAtLeast($0.version) }
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
            self.metas = filteredCategories.filter {
                 $0.header == CategoryHeader.minecraftServerMeta
            }
            self.serverFeatures = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerFeatures
            }
            self.plays = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerGameplay
            }
            self.communitys = filteredCategories.filter {
                $0.header == CategoryHeader.minecraftServerCommunity
            }
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
