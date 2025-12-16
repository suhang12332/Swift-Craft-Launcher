import SwiftUI

/// 游戏图标视图组件
/// 使用缓存机制优化图标加载性能，避免重复的文件系统访问
struct GameIconView: View {
    let gameName: String
    let iconName: String
    let size: CGFloat

    @State private var iconExists: Bool = false
    @State private var iconURL: URL?
    @State private var isLoading: Bool = false

    private let iconCache = GameIconCache.shared

    init(gameName: String, iconName: String, size: CGFloat = 16) {
        self.gameName = gameName
        self.iconName = iconName
        self.size = size
    }

    var body: some View {
        Group {
            if isLoading {
                if iconExists, let url = iconURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            defaultIcon
                        case .success(let image):
                            image
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        case .failure:
                            defaultIcon
                        @unknown default:
                            defaultIcon
                        }
                    }
                } else {
                    defaultIcon
                }
            } else {
                defaultIcon
                    .onAppear {
                        loadIconAsync()
                    }
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

    /// 异步加载图标信息
    private func loadIconAsync() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            // 先获取 URL（使用缓存）
            let url = iconCache.iconURL(gameName: gameName, iconName: iconName)

            // 异步检查文件存在性（在后台线程执行）
            let exists = await iconCache.iconExistsAsync(gameName: gameName, iconName: iconName)

            await MainActor.run {
                self.iconURL = url
                self.iconExists = exists
            }
        }
    }
}
