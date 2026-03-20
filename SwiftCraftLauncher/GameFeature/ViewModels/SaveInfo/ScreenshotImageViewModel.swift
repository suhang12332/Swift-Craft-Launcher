import Foundation
import AppKit

@MainActor
final class ScreenshotThumbnailViewModel: ObservableObject {
    @Published var image: NSImage?

    func load(path: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                }
            }
        }
    }

    func reset() {
        image = nil
    }
}

@MainActor
final class ScreenshotImageViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false

    func load(path: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let nsImage = NSImage(contentsOf: path) {
                DispatchQueue.main.async {
                    self.image = nsImage
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.loadFailed = true
                    self.isLoading = false
                }
            }
        }
    }

    func reset() {
        image = nil
        isLoading = true
        loadFailed = false
    }
}
