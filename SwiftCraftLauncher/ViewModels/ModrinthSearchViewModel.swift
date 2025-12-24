import SwiftUI

// MARK: - Constants
/// 定义 Modrinth 相关的常量
enum ModrinthConstants {
    // MARK: - UI Constants
    /// UI 相关的常量
    enum UIConstants {
        static let pageSize = 20
        static let iconSize: CGFloat = 48
        static let cornerRadius: CGFloat = 8
        static let tagCornerRadius: CGFloat = 6
        static let verticalPadding: CGFloat = 3
        static let tagHorizontalPadding: CGFloat = 3
        static let tagVerticalPadding: CGFloat = 1
        static let spacing: CGFloat = 3
        static let descriptionLineLimit = 1
        static let maxTags = 3
        static let contentSpacing: CGFloat = 8
    }

    // MARK: - API Constants
    /// API 相关的常量
    enum API {
        enum FacetType {
            static let projectType = "project_type"
            static let versions = "versions"
            static let categories = "categories"
            static let clientSide = "client_side"
            static let serverSide = "server_side"
            static let resolutions = "resolutions"
            static let performanceImpact = "performance_impact"
        }

        enum FacetValue {
            static let required = "required"
            static let optional = "optional"
            static let unsupported = "unsupported"
        }
    }
}

// MARK: - Filter Options
/// 过滤选项结构体，用于减少函数参数数量
struct FilterOptions {
    let resolutions: [String]
    let performanceImpact: [String]
    let loaders: [String]
}

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
    private var searchTask: Task<Void, Never>?
    private let pageSize: Int = 20

    // MARK: - Initialization
    init() {}

    deinit {
        searchTask?.cancel()
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

        searchTask = Task {
            do {
                if append {
                    isLoadingMore = true
                } else {
                    isLoading = true
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
                    // 转换 Modrinth 搜索参数为 CurseForge 搜索参数
                    // 注意：对于资源包（resourcepack），需要将分辨率（resolutions）一起映射到 CurseForge 的分类 ID
                    let cfParams = convertToCurseForgeParams(
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
                    result = CurseForgeToModrinthAdapter.convertSearchResult(cfResult)
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
    // MARK: - Private Methods
    private func buildFacets(
        projectType: String,
        versions: [String],
        categories: [String],
        features: [String],
        filterOptions: FilterOptions
    ) -> [[String]] {
        var facets: [[String]] = []

        // Project type is always required
        facets.append([
            "\(ModrinthConstants.API.FacetType.projectType):\(projectType)"
        ])

        // Add versions if any
        if !versions.isEmpty {
            facets.append(
                versions.map {
                    "\(ModrinthConstants.API.FacetType.versions):\($0)"
                }
            )
        }

        // Add categories if any
        if !categories.isEmpty {
            facets.append(
                categories.map {
                    "\(ModrinthConstants.API.FacetType.categories):\($0)"
                }
            )
        }

        // Handle client_side and server_side based on features selection
        let (clientFacets, serverFacets) = buildEnvironmentFacets(
            features: features
        )
        if !clientFacets.isEmpty {
            facets.append(clientFacets)
        }
        if !serverFacets.isEmpty {
            facets.append(serverFacets)
        }

        // Add resolutions if any (as categories)
        if !filterOptions.resolutions.isEmpty {
            facets.append(filterOptions.resolutions.map { "categories:\($0)" })
        }

        // Add performance impact if any (as categories)
        if !filterOptions.performanceImpact.isEmpty {
            facets.append(filterOptions.performanceImpact.map { "categories:\($0)" })
        }

        // Add loaders if any (as categories)
        if !filterOptions.loaders.isEmpty && projectType != "resourcepack"
            && projectType != "datapack" {
            var loadersToUse = filterOptions.loaders
            if let first = filterOptions.loaders.first, first.lowercased() == "vanilla" {
                loadersToUse = ["minecraft"]
            }
            facets.append(loadersToUse.map { "categories:\($0)" })
        }

        return facets
    }

    private func buildEnvironmentFacets(features: [String]) -> (
        clientFacets: [String], serverFacets: [String]
    ) {
        let hasClient = features.contains(AppConstants.EnvironmentTypes.client)
        let hasServer = features.contains(AppConstants.EnvironmentTypes.server)

        var clientFacets: [String] = []
        var serverFacets: [String] = []

        if hasClient {
            clientFacets.append("client_side:required")
        } else if hasServer {
            clientFacets.append("client_side:optional")
        }

        if hasServer {
            serverFacets.append("server_side:required")
        } else if hasClient {
            serverFacets.append("server_side:optional")
        }

        return (clientFacets, serverFacets)
    }

    /// 根据项目类型获取 CurseForge 的 classId
    private func classIdForProjectType(_ projectType: String) -> Int? {
        switch projectType.lowercased() {
        case "mod":
            return 6
        case "modpack":
            // CurseForge Minecraft Modpacks 的 classId
            return 4471
        case "resourcepack":
            return 12
        case "shader":
            return 6552
        case "datapack":
            return 6945
        default:
            return nil
        }
    }

    /// CurseForge 搜索参数结构
    private struct CurseForgeSearchParams {
        let classId: Int?
        let categoryIds: [Int]?
        let gameVersions: [String]?
        let searchFilter: String?
        let modLoaderTypes: [Int]?
    }

    /// 将 Modrinth 搜索参数转换为 CurseForge 搜索参数
    /// - Parameters:
    ///   - projectType: 项目类型
    ///   - versions: 游戏版本列表
    ///   - categories: 分类列表（行为/功能类）
    ///   - resolutions: 资源包分辨率列表（仅在 resourcepack 时生效）
    ///   - loaders: 加载器列表
    ///   - query: 搜索关键词
    /// - Returns: CurseForge 搜索参数
    /// - Note: API 限制：gameVersions 最多 4 个，modLoaderTypes 最多 5 个，categoryIds 最多 10 个
    private func convertToCurseForgeParams(
        projectType: String,
        versions: [String],
        categories: [String],
        resolutions: [String],
        loaders: [String],
        query: String
    ) -> CurseForgeSearchParams {
        // 转换项目类型为 classId
        let classId = classIdForProjectType(projectType)

        // 转换游戏版本列表（CurseForge API 限制：最多 4 个版本）
        let gameVersions: [String]?
        if !versions.isEmpty {
            gameVersions = Array(versions.prefix(4))
        } else {
            gameVersions = nil
        }

        // 转换分类（CurseForge 使用 categoryIds，从 Modrinth 分类名称映射）
        // 对于资源包（resourcepack），需要将行为分类 + 分辨率分类一起映射
        // API 限制：最多 10 个分类 ID
        let categoryIds: [Int]?
        let allCategoryNames: [String]
        if projectType.lowercased() == "resourcepack" {
            // 行为标签 + 分辨率标签 一起参与映射
            allCategoryNames = categories + resolutions
        } else {
            allCategoryNames = categories
        }

        if !allCategoryNames.isEmpty {
            let mappedIds = ModrinthToCurseForgeCategoryMapper.mapToCurseForgeCategoryIds(
                modrinthCategoryNames: allCategoryNames,
                projectType: projectType
            )
            categoryIds = mappedIds.isEmpty ? nil : mappedIds
        } else {
            categoryIds = nil
        }

        // 转换加载器列表为 modLoaderTypes
        // ModLoaderType: 1=Forge, 4=Fabric, 5=Quilt, 6=NeoForge
        // API 限制：最多 5 个加载器类型

        let modLoaderTypes: [Int]?

        if projectType == "resourcepack" || projectType == "shaderpack" || projectType == "datapack" {
            modLoaderTypes = nil
        } else {
            if !loaders.isEmpty {
                let loaderTypes = loaders.compactMap { loader -> Int? in
                    if let loaderType = CurseForgeModLoaderType.from(loader) {
                        return loaderType.rawValue
                    }
                    return nil
                }
                // 限制最多 5 个加载器类型
                modLoaderTypes = loaderTypes.isEmpty ? nil : Array(loaderTypes.prefix(5))
            } else {
                modLoaderTypes = nil
            }
        }

        // 搜索关键词（直接传原始 query，由 CurseForgeService 负责规范化为空格为 "+")
        let searchFilter = query.isEmpty ? nil : query

        return CurseForgeSearchParams(
            classId: classId,
            categoryIds: categoryIds,
            gameVersions: gameVersions,
            searchFilter: searchFilter,
            modLoaderTypes: modLoaderTypes
        )
    }
}
