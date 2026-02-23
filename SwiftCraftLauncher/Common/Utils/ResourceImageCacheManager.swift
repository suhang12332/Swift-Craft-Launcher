//
//  ResourceImageCacheManager.swift
//  SwiftCraftLauncher
//
//  Created by AI Assistant on 2026/2/17.
//

import SwiftUI
import Foundation

/// 资源图片缓存管理器
/// 为资源列表的图标提供高性能缓存，支持内存和磁盘两级缓存
final class ResourceImageCacheManager: @unchecked Sendable {
    // MARK: - Singleton
    static let shared = ResourceImageCacheManager()

    // MARK: - Properties
    /// 图片内存缓存：key 为 URL 字符串，value 为 NSImage
    private let imageCache: NSCache<NSString, NSImage>

    /// 共享的 URLSession，配置持久化缓存策略
    private let urlSession: URLSession

    // MARK: - Initialization
    private init() {
        // 配置内存缓存：最多缓存 30 张图片，总内存限制 5MB
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 5 * 1024 * 1024  // 5MB
        cache.name = "ResourceImageCache"
        self.imageCache = cache

        // 配置 URLSession 使用磁盘缓存
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,   // 2MB 内存缓存
            diskCapacity: 20 * 1024 * 1024,    // 20MB 磁盘缓存
            diskPath: "ResourceImageCache"
        )
        config.timeoutIntervalForRequest = 30
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Public Methods
    /// 加载图片（优先使用缓存）
    /// - Parameter url: 图片 URL
    /// - Returns: 加载的图片
    @MainActor
    func loadImage(from url: URL) async throws -> NSImage {
        let cacheKey = url.absoluteString as NSString

        // 1. 先检查内存缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 2. 从网络加载（URLSession 会自动使用磁盘缓存）
        let (data, _) = try await urlSession.data(from: url)

        // 3. 解析图片
        guard let image = NSImage(data: data) else {
            throw NSError(
                domain: "ResourceImageCacheManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"]
            )
        }

        // 4. 存入内存缓存
        let cost = data.count
        imageCache.setObject(image, forKey: cacheKey, cost: cost)

        return image
    }

    /// - Parameter urls: 图片 URL 列表
    func preloadImages(urls: [URL]) {
        Task(priority: .utility) { @MainActor in
            for url in urls {
                let cacheKey = url.absoluteString as NSString

                // 跳过已缓存的图片
                if self.imageCache.object(forKey: cacheKey) != nil {
                    continue
                }

                do {
                    _ = try await self.loadImage(from: url)
                } catch {
                    // 静默处理预加载失败
                    Logger.shared.debug("预加载图片失败: \(url.absoluteString)")
                }
            }
        }
    }

    /// 清理内存缓存（保留磁盘缓存）
    func clearMemoryCache() {
        imageCache.removeAllObjects()
    }

    /// 清理所有缓存（包括磁盘缓存）
    func clearAllCache() {
        imageCache.removeAllObjects()
        urlSession.configuration.urlCache?.removeAllCachedResponses()
    }

    /// 获取缓存统计信息（用于调试）
    func getCacheInfo() -> (memoryCount: Int, diskSize: Int) {
        let diskSize = urlSession.configuration.urlCache?.currentDiskUsage ?? 0
        // NSCache 不提供 count 属性，估算为已使用内存/平均图片大小
        return (memoryCount: 0, diskSize: diskSize)
    }
}

/// 带缓存的异步图片视图
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    // MARK: - Properties
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    private let cacheManager = ResourceImageCacheManager.shared

    // MARK: - Initialization
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    // MARK: - Body
    var body: some View {
        Group {
            if let image = image {
                content(Image(nsImage: image))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
        .onChange(of: url) { _, newUrl in
            if newUrl != url {
                loadImage()
            }
        }
    }

    // MARK: - Private Methods
    private func loadImage() {
        guard let url = url else { return }

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let loadedImage = try await cacheManager.loadImage(from: url)
                if !Task.isCancelled {
                    self.image = loadedImage
                }
            } catch {
                // 静默处理错误，显示占位符
                if !Task.isCancelled {
                    self.image = nil
                }
            }
        }
    }
}

// MARK: - Convenience Initializers
extension CachedAsyncImage where Content == Image, Placeholder == Color {
    /// 便捷初始化器：默认占位符为灰色背景
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0 },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
