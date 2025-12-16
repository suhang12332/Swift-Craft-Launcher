import SwiftUI
import CoreImage
import Foundation
import AppKit

// MARK: - Types and Constants

enum SkinType {
    case url, asset
}

// MARK: - Cache Wrapper

/// 包装渲染后的 CGImage 以便在 NSCache 中使用，并计算内存成本
/// 缓存裁剪后的 CGImage 而不是完整的 CIImage，可以显著减少内存占用
private class RenderedImageCache: NSObject {
    let headImage: CGImage  // 头部图像 (8x8)
    let layerImage: CGImage // 图层图像 (8x8)
    let cost: Int  // 内存成本（字节数）

    init(headImage: CGImage, layerImage: CGImage) {
        self.headImage = headImage
        self.layerImage = layerImage
        // 计算内存成本：两个 8x8 RGBA 图像 = 2 * 8 * 8 * 4 = 512 字节
        // 加上 CGImage 对象的开销，每个约 1KB，总计约 2.5KB
        let headCost = Int(headImage.width * headImage.height * 4)
        let layerCost = Int(layerImage.width * layerImage.height * 4)
        self.cost = headCost + layerCost + 2 * 1024  // 两个图像 + 对象开销
        super.init()
    }
}

private enum Constants {
    static let padding: CGFloat = 6
    static let networkTimeout: TimeInterval = 10.0

    // 缓存配置 - 优化后的配置
    // 缓存裁剪后的 CGImage (每个约 2.5KB)，而不是完整的 CIImage (每个约 20KB)
    // 这样可以缓存更多图像，同时使用更少的内存
    static let maxCacheSize = 100  // 最多缓存100个渲染后的图像（之前是50个完整图像）
    static let maxCacheMemory = 2 * 1024 * 1024  // 最多缓存2MB内存（约800个渲染后的图像）

    // Minecraft skin coordinates (64x64 format)
    static let headStartX: CGFloat = 8
    static let headStartY: CGFloat = 8
    static let headWidth: CGFloat = 8
    static let headHeight: CGFloat = 8

    // Skin layer coordinates (64x64 format)
    static let layerStartX: CGFloat = 40
    static let layerStartY: CGFloat = 8
    static let layerWidth: CGFloat = 8
    static let layerHeight: CGFloat = 8
}

// MARK: - Main Component
struct MinecraftSkinUtils: View {
    let type: SkinType
    let src: String
    let size: CGFloat

    @State private var renderedCache: RenderedImageCache?
    @State private var error: String?
    @State private var isLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    // 使用 NSCache 缓存渲染后的 CGImage，而不是完整的 CIImage
    // 这样可以显著减少内存占用：每个缓存项从 ~20KB 减少到 ~2.5KB
    private static let imageCache: NSCache<NSString, RenderedImageCache> = {
        let cache = NSCache<NSString, RenderedImageCache>()
        cache.countLimit = Constants.maxCacheSize
        cache.totalCostLimit = Constants.maxCacheMemory
        // 设置缓存名称，便于调试
        cache.name = "MinecraftSkinCache"
        return cache
    }()

    // 共享的 URLSession，避免每次请求都创建新的 session
    private static let sharedURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.networkTimeout
        config.timeoutIntervalForResource = Constants.networkTimeout
        // 使用缓存策略：允许使用本地缓存，但会验证服务器响应
        config.requestCachePolicy = .returnCacheDataElseLoad
        // 减少 URLSession 缓存大小，因为我们已经有了自己的缓存
        config.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,  // 2MB 内存缓存（从 5MB 减少）
            diskCapacity: 5 * 1024 * 1024,    // 5MB 磁盘缓存（从 10MB 减少）
            diskPath: "MinecraftSkinCache"
        )
        return URLSession(configuration: config)
    }()

    // 缓存统计（用于调试和监控）
    private static var cacheStats = CacheStats()

    // 确保内存压力监听只初始化一次
    private static var memoryObserverSetup = false
    private static let memoryObserverQueue = DispatchQueue(label: "com.swiftcraftlauncher.skincache.memory")
    // 保留定时器引用，避免被释放
    private static var cleanupTimer: Timer?
    // 保留通知观察者引用，以便后续移除
    private static var notificationObserver: NSObjectProtocol?

    private struct CacheStats {
        var hits: Int = 0
        var misses: Int = 0
        var evictions: Int = 0

        var hitRate: Double {
            let total = hits + misses
            return total > 0 ? Double(hits) / Double(total) : 0.0
        }
    }

    private static let ciContext: CIContext = {
        // Create CIContext with CPU-based rendering to avoid Metal shader cache conflicts
        // This is more appropriate for simple image cropping operations and prevents
        // Metal shader compilation lock file conflicts during development
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .name: "MinecraftSkinProcessor",
        ]
        let context = CIContext(options: options)
        // 初始化内存压力监听（只初始化一次）
        setupMemoryPressureObserverOnce()
        return context
    }()

    // 生成缓存键
    private var cacheKey: String {
        let typeString: String
        switch type {
        case .url:
            typeString = "url"
        case .asset:
            typeString = "asset"
        }
        return "\(typeString):\(src)"
    }

    // 获取缓存的渲染图像
    private static func getCachedRenderedImage(for key: String) -> RenderedImageCache? {
        let nsKey = key as NSString
        if let cache = imageCache.object(forKey: nsKey) {
            cacheStats.hits += 1
            return cache
        } else {
            cacheStats.misses += 1
            return nil
        }
    }

    // 渲染并缓存图像（裁剪后的 CGImage）
    private static func renderAndCacheImage(_ ciImage: CIImage, for key: String, context: CIContext) -> RenderedImageCache? {
        let nsKey = key as NSString

        // 检查是否已经缓存
        if let cached = imageCache.object(forKey: nsKey) {
            return cached
        }

        // 渲染头部图像
        let headRect = CGRect(
            x: Constants.headStartX,
            y: ciImage.extent.height - Constants.headStartY - Constants.headHeight,
            width: Constants.headWidth,
            height: Constants.headHeight
        )
        let headCropped = ciImage.cropped(to: headRect)

        // 渲染图层图像
        let layerRect = CGRect(
            x: Constants.layerStartX,
            y: ciImage.extent.height - Constants.layerStartY - Constants.layerHeight,
            width: Constants.layerWidth,
            height: Constants.layerHeight
        )
        let layerCropped = ciImage.cropped(to: layerRect)

        // 转换为 CGImage
        guard let headCGImage = context.createCGImage(headCropped, from: headCropped.extent),
              let layerCGImage = context.createCGImage(layerCropped, from: layerCropped.extent) else {
            return nil
        }

        // 创建缓存对象
        let cache = RenderedImageCache(headImage: headCGImage, layerImage: layerCGImage)
        imageCache.setObject(cache, forKey: nsKey, cost: cache.cost)
        return cache
    }

    // 清理缓存（用于内存压力时）
    static func clearCache() {
        imageCache.removeAllObjects()
        cacheStats = CacheStats()
        Logger.shared.debug("🧹 MinecraftSkinUtils 缓存已清理")
    }

    // 获取当前缓存配置（用于调试）
    static func getCacheInfo() -> (countLimit: Int, memoryLimit: Int, hitRate: Double) {
        return (
            countLimit: imageCache.countLimit,
            memoryLimit: imageCache.totalCostLimit,
            hitRate: cacheStats.hitRate
        )
    }

    // 获取缓存统计信息（用于调试）
    static func getCacheStats() -> (hits: Int, misses: Int, hitRate: Double) {
        return (
            hits: cacheStats.hits,
            misses: cacheStats.misses,
            hitRate: cacheStats.hitRate
        )
    }

    // 初始化内存压力监听（确保只初始化一次）
    private static func setupMemoryPressureObserverOnce() {
        memoryObserverQueue.sync {
            guard !memoryObserverSetup else { return }
            memoryObserverSetup = true

            // 通过监听应用进入后台时清理部分缓存
            notificationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // 应用失去焦点时，清理部分缓存以释放内存
                // 保留最近使用的 50% 的缓存（因为现在缓存的是更小的图像）
                let targetCount = Int(Double(Constants.maxCacheSize) * 0.5)
                if imageCache.countLimit > targetCount {
                    // 通过临时降低限制来触发清理
                    let originalLimit = imageCache.countLimit
                    imageCache.countLimit = targetCount
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        imageCache.countLimit = originalLimit
                    }
                    Logger.shared.debug("🧹 MinecraftSkinUtils: 应用失去焦点，清理部分缓存")
                }
            }

            // 定期清理缓存（每 5 分钟清理一次最旧的 20%）
            // 在主线程上创建定时器，并保留引用
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { _ in
                    let currentCount = imageCache.countLimit
                    let targetCount = Int(Double(currentCount) * 0.8)
                    if targetCount < currentCount {
                        let originalLimit = imageCache.countLimit
                        imageCache.countLimit = targetCount
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            imageCache.countLimit = originalLimit
                        }
                        Logger.shared.debug("🧹 MinecraftSkinUtils: 定期清理缓存（保留 80%）")
                    }
                }
                // 将定时器添加到 RunLoop 的 common modes，确保在滚动等操作时也能触发
                RunLoop.current.add(timer, forMode: .common)
                cleanupTimer = timer
            }
        }
    }

    init(type: SkinType, src: String, size: CGFloat = 64) {
        self.type = type
        self.src = src
        self.size = size
    }

    var body: some View {
        ZStack {
            if let cache = renderedCache {
                avatarLayers(for: cache)
            } else if isLoading {
                // Loading 指示器
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                }
            } else if error != nil {
                Image(systemName: "person.slash")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            // 先检查缓存
            if let cached = Self.getCachedRenderedImage(for: cacheKey) {
                self.renderedCache = cached
                self.isLoading = false
            } else {
                loadSkinData()
            }
        }
        .onChange(of: src) { _, _ in
            // 当 src 改变时，检查新缓存键（cacheKey 会根据新的 src 自动计算）
            if let cached = Self.getCachedRenderedImage(for: cacheKey) {
                self.renderedCache = cached
                self.isLoading = false
                self.error = nil
            } else {
                self.renderedCache = nil
                self.error = nil
                loadSkinData()
            }
        }
        .onDisappear {
            // 取消正在进行的任务，避免内存泄漏
            loadTask?.cancel()
            loadTask = nil
        }
    }

    @ViewBuilder
    private func avatarLayers(for cache: RenderedImageCache) -> some View {
        ZStack {
            // Head layer - 直接使用缓存的 CGImage，无需再次裁剪和转换
            Image(decorative: cache.headImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .frame(width: size * 0.9, height: size * 0.9)
                .clipped()
            // Skin layer (overlay) - 直接使用缓存的 CGImage
            Image(decorative: cache.layerImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .clipped()
        }
        .shadow(color: Color.black.opacity(0.6), radius: 1)
    }

    private func loadSkinData() {
        error = nil
        isLoading = true

        // 取消之前的任务
        loadTask?.cancel()

        loadTask = Task {
            do {
                // 检查任务是否被取消
                try Task.checkCancellation()

                Logger.shared.debug("Loading skin: \(src)")

                let data = try await loadData()

                try Task.checkCancellation()

                guard let ciImage = CIImage(data: data) else {
                    throw GlobalError.validation(
                        chineseMessage: "无效的图像数据",
                        i18nKey: "error.validation.invalid_image_data",
                        level: .silent
                    )
                }

                // Validate skin dimensions
                guard ciImage.extent.width == 64 && ciImage.extent.height == 64 else {
                    throw GlobalError.validation(
                        chineseMessage: "不支持的皮肤格式，仅支持64x64像素",
                        i18nKey: "error.validation.unsupported_skin_format",
                        level: .silent
                    )
                }

                try Task.checkCancellation()

                // 渲染并缓存图像（裁剪后的 CGImage）
                // 在后台线程进行渲染，避免阻塞主线程
                let cacheKeyValue = cacheKey
                let renderedCache = await Task.detached {
                    return await Self.renderAndCacheImage(ciImage, for: cacheKeyValue, context: Self.ciContext)
                }.value

                await MainActor.run {
                    self.renderedCache = renderedCache
                    self.isLoading = false
                }
            } catch is CancellationError {
                // 任务被取消，不需要处理
                await MainActor.run {
                    self.isLoading = false
                }
                return
            } catch {
                let globalError = GlobalError.from(error)
                await MainActor.run {
                    self.error = globalError.chineseMessage
                    self.isLoading = false
                }
                Logger.shared.error("❌ 皮肤加载失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
            }
        }
    }

    private func loadData() async throws -> Data {
        switch type {
        case .asset:
            return try await loadAssetData()
        case .url:
            return try await loadURLData()
        }
    }

    private func loadAssetData() async throws -> Data {
        guard let image = NSImage(named: src),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw GlobalError.resource(
                chineseMessage: "Asset 资源未找到: \(src)",
                i18nKey: "error.resource.asset_not_found",
                level: .silent
            )
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
            throw GlobalError.validation(
                chineseMessage: "无效的图像数据",
                i18nKey: "error.validation.invalid_image_data",
                level: .silent
            )
        }

        return data
    }

    private func loadURLData() async throws -> Data {
        guard let url = URL(string: src) else {
            throw GlobalError.validation(
                chineseMessage: "无效的URL: \(src)",
                i18nKey: "error.validation.invalid_url",
                level: .silent
            )
        }

        // 使用共享的 URLSession，避免每次请求都创建新的 session
        let (data, response) = try await Self.sharedURLSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GlobalError.download(
                chineseMessage: "皮肤下载失败: 无效的HTTP响应",
                i18nKey: "error.download.skin_download_failed",
                level: .silent
            )
        }

        switch httpResponse.statusCode {
        case 200: return data
        case 404:
            throw GlobalError.resource(
                chineseMessage: "皮肤资源未找到: \(src)",
                i18nKey: "error.resource.skin_not_found",
                level: .silent
            )
        case 408, 504:
            throw GlobalError.download(
                chineseMessage: "网络请求超时: \(src)",
                i18nKey: "error.download.network_timeout",
                level: .silent
            )
        default:
            throw GlobalError.download(
                chineseMessage: "皮肤下载失败: HTTP \(httpResponse.statusCode)",
                i18nKey: "error.download.skin_download_failed",
                level: .silent
            )
        }
    }
}
