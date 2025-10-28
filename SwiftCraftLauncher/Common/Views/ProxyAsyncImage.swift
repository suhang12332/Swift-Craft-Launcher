import SwiftUI
import Foundation

public struct ProxyAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var imagePhase: AsyncImagePhase = .empty
    @State private var loadingTask: Task<Void, Never>?
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { ProgressView() }
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content
    ) where Placeholder == ProgressView<EmptyView, EmptyView> {
        self.url = url
        self.content = { phase in
            switch phase {
            case .success(let image):
                return content(image) as! Content
            case .empty:
                return ProgressView() as! Content
            case .failure(_):
                return Image(systemName: "photo") as! Content
            @unknown default:
                return ProgressView() as! Content
            }
        }
        self.placeholder = { ProgressView() }
    }
    
    public var body: some View {
        content(imagePhase)
            .onAppear {
                loadImage()
            }
            .onChange(of: url) { _, _ in
                loadImage()
            }
            .onDisappear {
                loadingTask?.cancel()
            }
    }
    
    private func loadImage() {
        guard let url = url else {
            imagePhase = .empty
            return
        }
        
        // 取消之前的加载任务
        loadingTask?.cancel()
        
        // 重置状态
        imagePhase = .empty
        
        // 启动新的加载任务
        loadingTask = Task {
            do {
                let (data, _) = try await NetworkManager.shared.data(from: url)
                
                // 检查任务是否被取消
                if Task.isCancelled { return }
                
                if let nsImage = NSImage(data: data) {
                    await MainActor.run {
                        imagePhase = .success(Image(nsImage: nsImage))
                    }
                } else {
                    await MainActor.run {
                        imagePhase = .failure(ImageLoadError.invalidData)
                    }
                }
            } catch {
                // 检查任务是否被取消
                if Task.isCancelled { return }
                
                await MainActor.run {
                    imagePhase = .failure(error)
                }
            }
        }
    }
}

// 为了兼容性，添加一些便利的初始化方法
extension ProxyAsyncImage where Content == Image, Placeholder == ProgressView<EmptyView, EmptyView> {
    public init(url: URL?) {
        self.init(url: url) { phase in
            switch phase {
            case .success(let image):
                return image
            case .empty:
                return Image(systemName: "photo")
            case .failure(_):
                return Image(systemName: "photo")
            @unknown default:
                return Image(systemName: "photo")
            }
        }
    }
}

private enum ImageLoadError: Error {
    case invalidData
}