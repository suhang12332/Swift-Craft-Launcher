import Foundation
import AppKit

@MainActor
final class ScreenshotThumbnailViewModel: ObservableObject {
    @Published var image: NSImage?

    private var loadTask: Task<Void, Never>?

    func load(path: URL, thumbnailSize: CGFloat) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            let data = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: path)
            }.value

            guard !Task.isCancelled, let data else { return }
            self.image = ImageLoadingUtil.downsampledImage(
                data: data,
                maxPixelSize: thumbnailSize
            )
        }
    }

    func reset() {
        loadTask?.cancel()
        loadTask = nil
        image = nil
    }
}

@MainActor
final class ScreenshotImageViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false

    private var loadTask: Task<Void, Never>?

    func load(path: URL, maxPixelSize: CGFloat = 1600) {
        isLoading = true
        loadFailed = false

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }

            let data = await Task.detached(priority: .userInitiated) {
                try? Data(contentsOf: path)
            }.value

            if Task.isCancelled { return }

            let loaded = data.flatMap {
                ImageLoadingUtil.downsampledImage(data: $0, maxPixelSize: maxPixelSize)
            }

            self.image = loaded
            self.loadFailed = (loaded == nil)
            self.isLoading = false
        }
    }

    func reset() {
        loadTask?.cancel()
        loadTask = nil
        image = nil
        isLoading = true
        loadFailed = false
    }
}
