import SwiftUI

// MARK: - Constants
/// 定义 Modrinth 相关的常量
enum ModrinthConstants {
    // MARK: - UI Constants
    /// UI 相关的常量
    enum UI {
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

// MARK: - ViewModel
/// Modrinth 搜索视图模型
@MainActor
final class ModrinthSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var results: [ModrinthProject] = []
    @Published private(set) var isLoading = false
    @Published private(set) var totalHits = 0
    @Published private(set) var error: GlobalError?
    
    // MARK: - Properties
    let pageSize = ModrinthConstants.UI.pageSize
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    /// 执行搜索
    /// - Parameters:
    ///   - projectType: 项目类型
    ///   - page: 页码
    ///   - sortIndex: 排序索引
    ///   - versions: 版本列表
    ///   - categories: 分类列表
    ///   - features: 特性列表
    ///   - resolutions: 分辨率列表
    ///   - performanceImpact: 性能影响列表
    ///   - loaders: 加载器列表
    func search(
        projectType: String,
        page: Int = 1,
        query: String?,
        sortIndex: String,
        versions: [String] = [],
        categories: [String] = [],
        features: [String] = [],
        resolutions: [String] = [],
        performanceImpact: [String] = [],
        loaders: [String] = []
    ) async {
        // Cancel any existing search task
        searchTask?.cancel()
        
        searchTask = Task {
            isLoading = true
            error = nil
            
            let offset = (page - 1) * pageSize
            let facets = buildFacets(
                projectType: projectType,
                versions: versions,
                categories: categories,
                features: features,
                resolutions: resolutions,
                performanceImpact: performanceImpact,
                loaders: loaders
            )
            
            let result = await ModrinthService.searchProjects(
                facets: facets,
                index: sortIndex,
                offset: offset,
                limit: pageSize,
                query: query
            )
            
            if !Task.isCancelled {
                results = result.hits
                totalHits = result.totalHits
            }
            
            if !Task.isCancelled {
                isLoading = false
            }
        }
    }
    
    // MARK: - Private Methods
    private func buildFacets(
        projectType: String,
        versions: [String],
        categories: [String],
        features: [String],
        resolutions: [String],
        performanceImpact: [String],
        loaders: [String]
    ) -> [[String]] {
        var facets: [[String]] = []
        
        // Project type is always required
        facets.append(["\(ModrinthConstants.API.FacetType.projectType):\(projectType)"])
        
        // Add versions if any
        if !versions.isEmpty {
            facets.append(versions.map { "\(ModrinthConstants.API.FacetType.versions):\($0)" })
        }
        
        // Add categories if any
        if !categories.isEmpty {
            facets.append(categories.map { "\(ModrinthConstants.API.FacetType.categories):\($0)" })
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
        if !resolutions.isEmpty {
            facets.append(resolutions.map { "categories:\($0)" })
        }

        // Add performance impact if any (as categories)
        if !performanceImpact.isEmpty {
            facets.append(performanceImpact.map { "categories:\($0)" })
        }

        // Add loaders if any (as categories)
        if !loaders.isEmpty && projectType != "resourcepack" && projectType != "datapack" {
            var loadersToUse = loaders
            if let first = loaders.first, first.lowercased() == "vanilla" {
                loadersToUse = ["minecraft"]
            }
            facets.append(loadersToUse.map { "categories:\($0)" })
        }
        
        return facets
    }
    
    private func buildEnvironmentFacets(features: [String]) -> (
        clientFacets: [String], serverFacets: [String]
    ) {
        let hasClient = features.contains("client")
        let hasServer = features.contains("server")
        
        let clientFacets: [String]
        let serverFacets: [String]
        
        if hasClient && hasServer {
            clientFacets = ["\(ModrinthConstants.API.FacetType.clientSide):\(ModrinthConstants.API.FacetValue.required)"]
            serverFacets = ["\(ModrinthConstants.API.FacetType.serverSide):\(ModrinthConstants.API.FacetValue.required)"]
        } else if hasClient {
            clientFacets = [
                "\(ModrinthConstants.API.FacetType.clientSide):\(ModrinthConstants.API.FacetValue.optional)",
                "\(ModrinthConstants.API.FacetType.clientSide):\(ModrinthConstants.API.FacetValue.required)",
            ]
            serverFacets = [
                "\(ModrinthConstants.API.FacetType.serverSide):\(ModrinthConstants.API.FacetValue.optional)",
                "\(ModrinthConstants.API.FacetType.serverSide):\(ModrinthConstants.API.FacetValue.unsupported)",
            ]
        } else if hasServer {
            clientFacets = [
                "\(ModrinthConstants.API.FacetType.clientSide):\(ModrinthConstants.API.FacetValue.optional)",
                "\(ModrinthConstants.API.FacetType.clientSide):\(ModrinthConstants.API.FacetValue.unsupported)",
            ]
            serverFacets = [
                "\(ModrinthConstants.API.FacetType.serverSide):\(ModrinthConstants.API.FacetValue.optional)",
                "\(ModrinthConstants.API.FacetType.serverSide):\(ModrinthConstants.API.FacetValue.required)",
            ]
        } else {
            clientFacets = []
            serverFacets = []
        }
        
        return (clientFacets, serverFacets)
    }
    
    private func handleError(_ error: Error) {
        let globalError = GlobalError.from(error)
        Logger.shared.error("Modrinth 搜索错误: \(globalError.chineseMessage)")
        GlobalErrorHandler.shared.handle(globalError)
        Task { @MainActor in
            self.error = globalError
        }
    }
    
    deinit {
        searchTask?.cancel()
    }
} 
 
