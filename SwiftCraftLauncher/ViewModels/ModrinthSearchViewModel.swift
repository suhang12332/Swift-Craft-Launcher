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
    @Published private(set) var error: GlobalError?
    @Published private(set) var totalHits: Int = 0

    // MARK: - Private Properties
    private var searchTask: Task<Void, Never>?
    private var currentPage: Int = 1
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
        sortIndex: String,
        page: Int = 1
    ) async {
        // Cancel any existing search task
        searchTask?.cancel()

        searchTask = Task {
            do {
                isLoading = true
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

                let result = await ModrinthService.searchProjects(
                    facets: facets,
                    index: sortIndex,
                    offset: offset,
                    limit: pageSize,
                    query: query
                )

                try Task.checkCancellation()

                if !Task.isCancelled {
                    results = result.hits
                    totalHits = result.totalHits
                }

                try Task.checkCancellation()

                if !Task.isCancelled {
                    isLoading = false
                }
            } catch is CancellationError {
                // 任务被取消，不需要处理
                return
            } catch {
                let globalError = GlobalError.from(error)
                if !Task.isCancelled {
                    self.error = globalError
                    self.isLoading = false
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
}
