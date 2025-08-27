import SwiftUI
import CoreImage

// MARK: - Types and Constants

enum SkinType {
    case url, asset
}

private enum Constants {
    static let padding: CGFloat = 6
    static let networkTimeout: TimeInterval = 10.0
    static let maxCacheSize = 50
    
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

// MARK: - Image Cache

private actor ImageCache {
    private var cache: [String: CIImage] = [:]
    
    func get(for key: String) -> CIImage? { cache[key] }
    
    func set(_ image: CIImage, for key: String) {
        if cache.count >= Constants.maxCacheSize {
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        cache[key] = image
    }
    
    func clear() { cache.removeAll() }
    
    // 添加清理方法，避免内存泄漏
    func cleanup() {
        cache.removeAll()
    }
}

// MARK: - Main Component

struct MinecraftSkinUtils: View {
    let type: SkinType
    let src: String
    let size: CGFloat
    
    @State private var image: CIImage?
    @State private var error: String?
    @State private var loadTask: Task<Void, Never>?
    
    private static let ciContext = CIContext()
    private static let imageCache = ImageCache()
    
    init(type: SkinType, src: String, size: CGFloat = 64) {
        self.type = type
        self.src = src
        self.size = size
    }

    var body: some View {
        ZStack {
            if let image = image {
                avatarLayers(for: image)
            } else if let _ = error {
                Image(systemName: "person.slash")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
        .frame(width: size, height: size)
        .onAppear { loadSkinData() }
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
            
        }.shadow(color: Color.black.opacity(0.6), radius: 1)
    }
    
    private func loadSkinData() {
        error = nil
        
        // 取消之前的任务
        loadTask?.cancel()
        
        loadTask = Task {
            do {
                // 检查任务是否被取消
                try Task.checkCancellation()
                
                if let cachedImage = await Self.imageCache.get(for: src) {
                    try Task.checkCancellation()
                    await MainActor.run {
                        self.image = cachedImage
                    }
                    return
                }
                
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
                
                await Self.imageCache.set(ciImage, for: src)
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.image = ciImage
                }
                
            } catch is CancellationError {
                // 任务被取消，不需要处理
                return
            } catch {
                let globalError = GlobalError.from(error)
                await MainActor.run {
                    self.error = globalError.chineseMessage
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
        
        let (data, response) = try await NetworkManager.shared.data(from: url)
        
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
        return context.createCGImage(croppedImage, from: croppedImage.extent)
    }
}


