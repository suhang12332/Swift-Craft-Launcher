import Foundation

extension ModrinthSearchViewModel {
    struct SearchCachePayload: Codable {
        let hits: [ModrinthProject]
        let totalHits: Int
        let updatedAt: Date
    }

    struct SearchCacheContext {
        let query: String
        let projectType: String
        let versions: [String]
        let categories: [String]
        let features: [String]
        let resolutions: [String]
        let performanceImpact: [String]
        let loaders: [String]
        let dataSource: DataSource
    }
}
