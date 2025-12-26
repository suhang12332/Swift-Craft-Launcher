import SwiftUI
import Combine

/// 游戏图标视图组件
/// 使用缓存机制优化图标加载性能，避免重复的文件系统访问
struct GameIconView: View {
    let gameName: String
    let iconName: String
    let size: CGFloat

    @State private var iconExists: Bool
    @State private var iconURL: URL?
    @State private var hasLoaded: Bool
    @State private var cachedImage: NSImage?
    @State private var refreshTrigger: UUID = UUID()

    private let iconCache = GameIconCache.shared

    init(gameName: String, iconName: String, size: CGFloat = 16) {
        self.gameName = gameName
        self.iconName = iconName
        self.size = size

        // 在初始化时立即检查缓存，设置初始状态
        let cache = GameIconCache.shared
        let url = cache.iconURL(gameName: gameName, iconName: iconName)
        let cachedExists = cache.cachedIconExists(gameName: gameName, iconName: iconName)

        // 使用 State 的初始化器设置初始值
        _iconURL = State(initialValue: url)
        _iconExists = State(initialValue: cachedExists ?? false)
        _hasLoaded = State(initialValue: cachedExists != nil)

        // 如果缓存中有结果且文件存在，立即加载图片
        if cachedExists == true, let image = NSImage(contentsOf: url) {
            _cachedImage = State(initialValue: image)
        } else {
            _cachedImage = State(initialValue: nil)
        }
    }

    var body: some View {
        Group {
            if iconExists, iconURL != nil {
                // 只使用缓存的图片，避免在 body 中同步加载
                if let nsImage = cachedImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    // 如果图片还没加载，显示默认图标，同时异步加载
                    defaultIcon
                }
            } else {
                defaultIcon
            }
        }
        .task(id: refreshTrigger) {
            // 当 refreshTrigger 改变时，重新加载图标
            await reloadIcon()
        }
        .onReceive(iconCache.cacheInvalidationPublisher) { invalidatedGameName in
            // 监听缓存失效通知
            // 如果通知的游戏名称匹配，或者通知为 nil（清除所有缓存），则刷新
            if invalidatedGameName == nil || invalidatedGameName == gameName {
                refreshTrigger = UUID()
            }
        }
    }

    private var defaultIcon: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .interpolation(.none)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// 重新加载图标（当缓存失效时调用）
    private func reloadIcon() async {
        // 重置状态，确保完全重新加载
        await MainActor.run {
            self.hasLoaded = false
            self.cachedImage = nil
            self.iconExists = false
            // iconURL 会在 loadIconAsync 中重新设置
        }

        // 重新加载图标
        await loadIconAsync()
    }

    /// 异步加载图标信息
    /// 只在缓存中没有结果时调用
    private func loadIconAsync() async {
        // 如果 URL 还没有设置，先设置
        let url = iconCache.iconURL(gameName: gameName, iconName: iconName)
        await MainActor.run {
            self.iconURL = url
        }

        // 异步检查文件存在性（优先使用缓存）
        let exists = await iconCache.iconExistsAsync(gameName: gameName, iconName: iconName)

        await MainActor.run {
            self.iconExists = exists
            self.hasLoaded = true

            // 如果文件存在，加载图片
            if exists, let url = self.iconURL {
                if let image = NSImage(contentsOf: url) {
                    self.cachedImage = image
                }
            }
        }
    }

    /// 异步加载图片
    private func loadImageAsync(url: URL) async {
        // 在后台线程加载图片数据（Data 是 Sendable）
        let imageData = await Task.detached {
            try? Data(contentsOf: url)
        }.value

        // 在主线程创建 NSImage（NSImage 不是 Sendable，需要在主线程创建）
        await MainActor.run {
            if let data = imageData {
                self.cachedImage = NSImage(data: data)
            }
        }
    }
}
