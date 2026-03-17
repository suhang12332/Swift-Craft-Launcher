//
//  ContributorAvatarView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import Foundation

/// 贡献者头像图片缓存管理器
/// 使用 NSCache 限制内存占用，避免加载过多图片导致内存溢出
final class ContributorAvatarCache: @unchecked Sendable {
    static let shared = ContributorAvatarCache()

    /// 图片缓存：key 为 URL 字符串，value 为 NSImage
    private let imageCache: NSCache<NSString, NSImage>

    /// 磁盘缓存目录（位于系统 Caches 目录下）
    private static let diskCachePath: String = {
        let fm = FileManager.default
        let dir = AppPaths.appCache.appendingPathComponent("ContributorAvatarCache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }()

    /// 共享的 URLSession，启用缓存以减少内存占用
    private let urlSession: URLSession

    private init() {
        // 设置缓存限制：最多缓存 30 张图片，总内存限制 3MB
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 3 * 1024 * 1024  // 3MB
        cache.name = "ContributorAvatarCache"
        self.imageCache = cache

        // 配置 URLSession 使用较小的缓存
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 1 * 1024 * 1024,  // 1MB 内存缓存
            diskCapacity: 5 * 1024 * 1024,    // 5MB 磁盘缓存
            diskPath: Self.diskCachePath
        )
        self.urlSession = URLSession(configuration: config)
    }

    /// 加载图片
    @MainActor
    func loadImage(from url: URL, targetSize: CGFloat) async throws -> NSImage {
        let cacheKey = "\(url.absoluteString)#\(Int(targetSize * 2))" as NSString

        // 先检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 从网络加载
        let (data, _) = try await urlSession.data(from: url)
        guard let image = ImageLoadingUtil.downsampledImage(
            data: data,
            maxPixelSize: targetSize
        ) ?? NSImage(data: data) else {
            throw NSError(domain: "ContributorAvatarCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"])
        }

        // 计算图片大小（用于缓存成本）
        let cost = ImageLoadingUtil.imageMemoryCost(image)
        imageCache.setObject(image, forKey: cacheKey, cost: cost)

        return image
    }

    /// 清理缓存
    func clearCache() {
        imageCache.removeAllObjects()
    }
}

/// 贡献者头像视图
struct ContributorAvatarView: View {
    let avatarUrl: String
    let size: CGFloat

    @StateObject private var viewModel = ContributorAvatarViewModel()

    init(avatarUrl: String, size: CGFloat = 32) {
        self.avatarUrl = avatarUrl
        self.size = size
    }

    var body: some View {
        Group {
            if let image = viewModel.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if viewModel.isLoading {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            viewModel.load(avatarUrl: avatarUrl, size: size)
        }
        .onDisappear {
            viewModel.cancel()
        }
    }
}

/// 静态贡献者头像图片缓存管理器
final class StaticContributorAvatarCache: @unchecked Sendable {
    static let shared = StaticContributorAvatarCache()

    /// 图片缓存：key 为 URL 字符串，value 为 NSImage
    private let imageCache: NSCache<NSString, NSImage>

    /// 磁盘缓存目录（位于系统 Caches 目录下）
    private static let diskCachePath: String = {
        let fm = FileManager.default
        let dir = AppPaths.appCache.appendingPathComponent("StaticContributorAvatarCache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }()

    /// 共享的 URLSession，启用缓存以减少内存占用
    private let urlSession: URLSession

    private init() {
        // 设置缓存限制：最多缓存 20 张图片，总内存限制 2MB
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 20
        cache.totalCostLimit = 2 * 1024 * 1024  // 2MB
        cache.name = "StaticContributorAvatarCache"
        self.imageCache = cache

        // 配置 URLSession 使用较小的缓存
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 1 * 1024 * 1024,  // 1MB 内存缓存
            diskCapacity: 5 * 1024 * 1024,    // 5MB 磁盘缓存
            diskPath: Self.diskCachePath
        )
        self.urlSession = URLSession(configuration: config)
    }

    /// 加载图片
    @MainActor
    func loadImage(from url: URL, targetSize: CGFloat) async throws -> NSImage {
        let cacheKey = "\(url.absoluteString)#\(Int(targetSize * 2))" as NSString

        // 先检查缓存
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // 从网络加载
        let (data, _) = try await urlSession.data(from: url)
        guard let image = ImageLoadingUtil.downsampledImage(
            data: data,
            maxPixelSize: targetSize
        ) ?? NSImage(data: data) else {
            throw NSError(domain: "StaticContributorAvatarCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"])
        }

        // 计算图片大小（用于缓存成本）
        let cost = ImageLoadingUtil.imageMemoryCost(image)
        imageCache.setObject(image, forKey: cacheKey, cost: cost)

        return image
    }

    /// 清理缓存
    func clearCache() {
        imageCache.removeAllObjects()
    }
}

/// 静态贡献者头像视图（支持 emoji）
struct StaticContributorAvatarView: View {
    let avatar: String
    let size: CGFloat

    @StateObject private var viewModel = StaticContributorAvatarViewModel()

    init(avatar: String, size: CGFloat = 32) {
        self.avatar = avatar
        self.size = size
    }

    var body: some View {
        Group {
            if avatar.starts(with: "http") {
                Group {
                    if let image = viewModel.image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if viewModel.isLoading {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                    } else {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .onAppear {
                    viewModel.load(avatar: avatar, size: size)
                }
                .onDisappear {
                    viewModel.cancel()
                }
            } else {
                Text(avatar)
                    .font(.system(size: 24))
                    .frame(width: size, height: size)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
}
