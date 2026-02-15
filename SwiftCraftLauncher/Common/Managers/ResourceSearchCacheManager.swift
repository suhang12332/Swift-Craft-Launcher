//
//  ResourceSearchCacheManager.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2026/2/15.
//

import Foundation

// MARK: - Cache Entry
/// 搜索结果缓存条目
struct SearchCacheEntry {
    let results: [ModrinthProject]
    let totalHits: Int
    let timestamp: Date
    let page: Int
}

// MARK: - Cache Key
/// 搜索缓存键，用于唯一标识一次搜索
struct SearchCacheKey: Hashable {
    let query: String
    let projectType: String
    let versions: [String]
    let categories: [String]
    let features: [String]
    let resolutions: [String]
    let performanceImpact: [String]
    let loaders: [String]
    let page: Int
    let dataSource: DataSource
    func hash(into hasher: inout Hasher) {
        hasher.combine(query)
        hasher.combine(projectType)
        hasher.combine(versions.joined(separator: ","))
        hasher.combine(categories.joined(separator: ","))
        hasher.combine(features.joined(separator: ","))
        hasher.combine(resolutions.joined(separator: ","))
        hasher.combine(performanceImpact.joined(separator: ","))
        hasher.combine(loaders.joined(separator: ","))
        hasher.combine(page)
        hasher.combine(dataSource.rawValue)
    }
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.query == rhs.query &&
        lhs.projectType == rhs.projectType &&
        lhs.versions == rhs.versions &&
        lhs.categories == rhs.categories &&
        lhs.features == rhs.features &&
        lhs.resolutions == rhs.resolutions &&
        lhs.performanceImpact == rhs.performanceImpact &&
        lhs.loaders == rhs.loaders &&
        lhs.page == rhs.page &&
        lhs.dataSource == rhs.dataSource
    }
}

// MARK: - Cache Manager
/// 资源搜索缓存管理器
@MainActor
final class ResourceSearchCacheManager {
    // MARK: - Singleton
    static let shared = ResourceSearchCacheManager()
    // MARK: - Properties
    private var cache: [SearchCacheKey: SearchCacheEntry] = [:]
    private let cacheTimeout: TimeInterval = 300 // 5分钟
    private let maxCacheSize: Int = 50 // 最多缓存50个搜索结果
    // MARK: - Initialization
    private init() {}
    // MARK: - Public Methods
    /// 获取缓存的搜索结果
    /// - Parameter key: 搜索缓存键
    /// - Returns: 如果缓存存在且有效，返回缓存的搜索结果，否则返回 nil
    func getCachedResult(for key: SearchCacheKey) -> SearchCacheEntry? {
        guard let entry = cache[key] else {
            return nil
        }
        // 检查缓存是否过期
        let timeElapsed = Date().timeIntervalSince(entry.timestamp)
        if timeElapsed > cacheTimeout {
            // 缓存已过期，移除并返回 nil
            cache.removeValue(forKey: key)
            return nil
        }
        return entry
    }
    /// 缓存搜索结果
    /// - Parameters:
    ///   - key: 搜索缓存键
    ///   - results: 搜索结果列表
    ///   - totalHits: 总结果数
    ///   - page: 当前页码
    func cacheResult(for key: SearchCacheKey, results: [ModrinthProject], totalHits: Int, page: Int) {
        let entry = SearchCacheEntry(
            results: results,
            totalHits: totalHits,
            timestamp: Date(),
            page: page
        )
        cache[key] = entry
        // 检查缓存大小，如果超过限制则清理最旧的条目
        cleanupIfNeeded()
    }
    /// 清除所有缓存
    func clearAll() {
        cache.removeAll()
    }
    /// 清除特定项目类型的缓存
    /// - Parameter projectType: 项目类型
    func clear(for projectType: String) {
        cache = cache.filter { key, _ in
            key.projectType != projectType
        }
    }
    /// 清除特定数据源的缓存
    /// - Parameter dataSource: 数据源
    func clear(for dataSource: DataSource) {
        cache = cache.filter { key, _ in
            key.dataSource != dataSource
        }
    }
    // MARK: - Private Methods
    /// 清理缓存，如果超过最大缓存大小
    private func cleanupIfNeeded() {
        guard cache.count > maxCacheSize else { return }
        // 找出最旧的条目
        let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        // 移除最旧的条目，直到缓存大小在限制内
        let entriesToRemove = sortedEntries.prefix(cache.count - maxCacheSize)
        for (key, _) in entriesToRemove {
            cache.removeValue(forKey: key)
        }
    }
}
