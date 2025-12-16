import SwiftUI
import CoreImage
import Foundation

// MARK: - Types and Constants

enum SkinType {
    case url, asset
}

// MARK: - Cache Wrapper

/// 包装 CIImage 以便在 NSCache 中使用
private class CIImageWrapper: NSObject {
    let image: CIImage

    init(_ image: CIImage) {
        self.image = image
    }
}

private enum Constants {
    static let padding: CGFloat = 6
    static let networkTimeout: TimeInterval = 10.0

    // 缓存配置
    static let maxCacheSize = 50  // 最多缓存50个图像，约800KB-1.6MB内存

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

    @State private var image: CIImage?
    @State private var error: String?
    @State private var isLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    // 使用 NSCache 进行线程安全的图像缓存
    // NSCache 会在内存压力时自动清理，并支持设置最大对象数量
    private static let imageCache: NSCache<NSString, CIImageWrapper> = {
        let cache = NSCache<NSString, CIImageWrapper>()
        cache.countLimit = Constants.maxCacheSize
        return cache
    }()

    private static let ciContext: CIContext = {
        // Create CIContext with CPU-based rendering to avoid Metal shader cache conflicts
        // This is more appropriate for simple image cropping operations and prevents
        // Metal shader compilation lock file conflicts during development
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: true,
            .cacheIntermediates: false,
            .name: "MinecraftSkinProcessor",
        ]
        return CIContext(options: options)
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

    // 获取缓存的图像
    private static func getCachedImage(for key: String) -> CIImage? {
        let nsKey = key as NSString
        return imageCache.object(forKey: nsKey)?.image
    }

    // 设置缓存的图像
    private static func setCachedImage(_ image: CIImage, for key: String) {
        let nsKey = key as NSString
        let wrapper = CIImageWrapper(image)
        imageCache.setObject(wrapper, forKey: nsKey)
    }

    // 清理缓存（用于内存压力时）
    static func clearCache() {
        imageCache.removeAllObjects()
    }

    // 获取当前缓存大小（用于调试）
    // 注意：NSCache 不提供直接获取对象数量的方法，这里返回 countLimit
    static func getCacheSize() -> Int {
        return imageCache.countLimit
    }

    init(type: SkinType, src: String, size: CGFloat = 64) {
        self.type = type
        self.src = src
        self.size = size
    }

    var body: some View {
        ZStack {
            if let image = image {
                avatarLayers(for: image)
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
            if let cachedImage = Self.getCachedImage(for: cacheKey) {
                self.image = cachedImage
                self.isLoading = false
            } else {
                loadSkinData()
            }
        }
        .onChange(of: src) { _, _ in
            // 当 src 改变时，检查新缓存键（cacheKey 会根据新的 src 自动计算）
            if let cachedImage = Self.getCachedImage(for: cacheKey) {
                self.image = cachedImage
                self.isLoading = false
                self.error = nil
            } else {
                self.image = nil
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
    private func avatarLayers(for image: CIImage) -> some View {
        ZStack {
            // Head layer
            CropImageView(
                ciImage: image,
                startX: Constants.headStartX,
                startY: Constants.headStartY,
                context: Self.ciContext,
                size: size * 0.9
            )
            // Skin layer (overlay)
            CropImageView(
                ciImage: image,
                startX: Constants.layerStartX,
                startY: Constants.layerStartY,
                context: Self.ciContext,
                size: size
            )
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

                // 缓存图像
                Self.setCachedImage(ciImage, for: cacheKey)

                await MainActor.run {
                    self.image = ciImage
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

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Constants.networkTimeout
        config.timeoutIntervalForResource = Constants.networkTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        let session = URLSession(configuration: config)
        let (data, response) = try await session.data(from: url)

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

// MARK: - Skin Layer View

struct CropImageView: View {
    let ciImage: CIImage
    let startX: CGFloat
    let startY: CGFloat
    let context: CIContext
    let size: CGFloat

    var body: some View {
        if let cgImage = createCroppedImage() {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .frame(width: size, height: size)
                .clipped()
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }

    private func createCroppedImage() -> CGImage? {
        let imageHeight = ciImage.extent.height
        let convertedY = imageHeight - startY - 8

        let croppedRect = CGRect(
            x: startX,
            y: convertedY,
            width: 8,
            height: 8
        )

        let croppedImage = ciImage.cropped(to: croppedRect)

        // Use autoreleasepool to ensure proper memory management
        return autoreleasepool {
            return context.createCGImage(croppedImage, from: croppedImage.extent)
        }
    }
}
