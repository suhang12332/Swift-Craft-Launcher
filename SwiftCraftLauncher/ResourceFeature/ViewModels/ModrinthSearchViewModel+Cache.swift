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

    func cacheKey(context: SearchCacheContext) -> String {
        let keyParts = [
            "q:\(context.query)",
            "type:\(context.projectType)",
            "v:\(context.versions.sorted().joined(separator: ","))",
            "c:\(context.categories.sorted().joined(separator: ","))",
            "f:\(context.features.sorted().joined(separator: ","))",
            "r:\(context.resolutions.sorted().joined(separator: ","))",
            "p:\(context.performanceImpact.sorted().joined(separator: ","))",
            "l:\(context.loaders.sorted().joined(separator: ","))",
            "ds:\(context.dataSource.rawValue)",
        ]
        return keyParts.joined(separator: "|")
    }

    func loadCachedFirstPageAsync(cacheKey: String) async -> SearchCachePayload? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let cached: SearchCachePayload? = AppCacheManager.shared.get(
                    namespace: self.cacheNamespace,
                    key: cacheKey,
                    as: SearchCachePayload.self
                )
                continuation.resume(returning: cached)
            }
        }
    }

    func saveFirstPageCache(cacheKey: String, hits: [ModrinthProject], totalHits: Int) {
        let payload = SearchCachePayload(
            hits: Array(hits.prefix(maxRetainedResults)),
            totalHits: totalHits,
            updatedAt: Date()
        )
        AppCacheManager.shared.setSilently(
            namespace: cacheNamespace,
            key: cacheKey,
            value: payload
        )
    }
}
