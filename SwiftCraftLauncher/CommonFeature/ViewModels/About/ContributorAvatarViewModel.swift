import Foundation
import SwiftUI

@MainActor
final class ContributorAvatarViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = false

    private var loadTask: Task<Void, Never>?

    func load(avatarUrl: String, size: CGFloat) {
        guard let url = optimizedAvatarURL(from: avatarUrl, size: size) else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            do {
                let loadedImage = try await ContributorAvatarCache.shared.loadImage(from: url)
                if !Task.isCancelled {
                    self.image = loadedImage
                }
            } catch {
                if !Task.isCancelled {
                    self.image = nil
                }
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func optimizedAvatarURL(from rawUrl: String, size: CGFloat) -> URL? {
        guard let url = URL(string: rawUrl.httpToHttps()) else { return nil }

        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            let pixelSize = Int(size * 2)
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }
}

@MainActor
final class StaticContributorAvatarViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading: Bool = false

    private var loadTask: Task<Void, Never>?

    func load(avatar: String, size: CGFloat) {
        guard let url = optimizedAvatarURL(from: avatar, size: size) else { return }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            self.isLoading = true
            defer { self.isLoading = false }

            do {
                let loadedImage = try await StaticContributorAvatarCache.shared.loadImage(from: url)
                if !Task.isCancelled {
                    self.image = loadedImage
                }
            } catch {
                if !Task.isCancelled {
                    self.image = nil
                }
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func optimizedAvatarURL(from avatar: String, size: CGFloat) -> URL? {
        guard avatar.starts(with: "http"), let url = URL(string: avatar) else { return nil }

        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            let pixelSize = Int(size * 2)
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }
}
