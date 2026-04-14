//
//  ContributorAvatarView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI
import Foundation

/// 贡献者头像视图
struct ContributorAvatarView: View {
    let avatarUrl: String
    let size: CGFloat

    init(avatarUrl: String, size: CGFloat = 32) {
        self.avatarUrl = avatarUrl
        self.size = size
    }

    var body: some View {
        AvatarRemoteImageView(rawValue: avatarUrl, size: size)
    }
}

/// 静态贡献者头像视图（支持 emoji）
struct StaticContributorAvatarView: View {
    let avatar: String
    let size: CGFloat

    init(avatar: String, size: CGFloat = 32) {
        self.avatar = avatar
        self.size = size
    }

    var body: some View {
        if isRemoteAvatarURLString(avatar) {
            AvatarRemoteImageView(rawValue: avatar, size: size)
        } else {
            Text(avatar)
                .font(.system(size: 24))
                .frame(width: size, height: size)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

private struct AvatarRemoteImageView: View {
    let rawValue: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url = optimizedAvatarURL(from: rawValue, size: size) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .empty:
                        avatarPlaceholder(showLoading: true)
                    case .failure:
                        avatarPlaceholder()
                    @unknown default:
                        avatarPlaceholder()
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: url)
                    )
                }
            } else {
                avatarPlaceholder()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

private func avatarPlaceholder(showLoading: Bool = false) -> some View {
    Rectangle()
        .foregroundColor(.gray.opacity(0.3))
        .overlay {
            if showLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
}

private func isRemoteAvatarURLString(_ value: String) -> Bool {
    guard let scheme = URLComponents(string: value)?.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
}

private func optimizedAvatarURL(from rawValue: String, size: CGFloat) -> URL? {
    guard isRemoteAvatarURLString(rawValue), let url = URL(string: rawValue.httpToHttps()) else { return nil }

    if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
        let pixelSize = Int(size * 2)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
        return components?.url
    }

    return url
}
