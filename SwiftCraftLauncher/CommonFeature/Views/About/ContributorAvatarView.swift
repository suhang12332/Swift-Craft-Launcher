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
            diskPath: "ContributorAvatarCache"
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

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    init(avatarUrl: String, size: CGFloat = 32) {
        self.avatarUrl = avatarUrl
        self.size = size
    }

    /// 获取优化后的头像 URL（使用 GitHub 的缩略图参数）
    /// GitHub 支持 ?s=size 参数来获取指定大小的图片，减少下载大小
    private var optimizedAvatarURL: URL? {
        guard let url = URL(string: avatarUrl.httpToHttps()) else { return nil }

        // 如果已经是 GitHub 头像 URL，添加大小参数
        // GitHub 头像 URL 格式: https://avatars.githubusercontent.com/u/xxx 或 https://github.com/identicons/xxx.png
        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            // 计算需要的像素大小（@2x 屏幕需要 2 倍）
            let pixelSize = Int(size * 2)
            // 移除现有的查询参数（如果有）
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
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
            loadImage()
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private func loadImage() {
        guard let url = optimizedAvatarURL else { return }

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let loadedImage = try await ContributorAvatarCache.shared.loadImage(from: url, targetSize: size)
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

/// 静态贡献者头像图片缓存管理器
final class StaticContributorAvatarCache: @unchecked Sendable {
    static let shared = StaticContributorAvatarCache()

    /// 图片缓存：key 为 URL 字符串，value 为 NSImage
    private let imageCache: NSCache<NSString, NSImage>

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
            diskPath: "StaticContributorAvatarCache"
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

    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?

    init(avatar: String, size: CGFloat = 32) {
        self.avatar = avatar
        self.size = size
    }

    /// 获取优化后的头像 URL（使用 GitHub 的缩略图参数）
    private var optimizedAvatarURL: URL? {
        guard avatar.starts(with: "http"), let url = URL(string: avatar) else { return nil }

        // 如果已经是 GitHub 头像 URL，添加大小参数
        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            // 计算需要的像素大小（@2x 屏幕需要 2 倍）
            let pixelSize = Int(size * 2)
            // 移除现有的查询参数（如果有）
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }

    var body: some View {
        Group {
            if avatar.starts(with: "http") {
                Group {
                    if let image = image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if isLoading {
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
                    loadImage()
                }
                .onDisappear {
                    loadTask?.cancel()
                    loadTask = nil
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

    private func loadImage() {
        guard let url = optimizedAvatarURL else { return }

        loadTask?.cancel()
        loadTask = Task { @MainActor in
            isLoading = true
            defer { isLoading = false }

            do {
                let loadedImage = try await StaticContributorAvatarCache.shared.loadImage(from: url, targetSize: size)
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
