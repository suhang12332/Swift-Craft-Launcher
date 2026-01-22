//
//  ContributorAvatarView.swift
//  SwiftCraftLauncher
//
//

import SwiftUI

/// 贡献者头像视图
struct ContributorAvatarView: View {
    let avatarUrl: String
    let size: CGFloat

    init(avatarUrl: String, size: CGFloat = 32) {
        self.avatarUrl = avatarUrl
        self.size = size
    }

    // 共享的 URLSession，启用缓存以减少内存占用
    private static let cachedURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        // 启用缓存策略，减少重复下载
        config.requestCachePolicy = .returnCacheDataElseLoad
        // 限制缓存大小，避免占用过多内存
        config.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,  // 2MB 内存缓存
            diskCapacity: 10 * 1024 * 1024,   // 10MB 磁盘缓存
            diskPath: "ContributorAvatarCache"
        )
        return URLSession(configuration: config)
    }()

    /// 获取优化后的头像 URL（使用 GitHub 的缩略图参数）
    /// GitHub 支持 ?s=size 参数来获取指定大小的图片，减少下载大小
    private var optimizedAvatarURL: URL? {
        guard let url = URL(string: avatarUrl.httpToHttps()) else { return nil }

        // 如果已经是 GitHub 头像 URL，添加大小参数
        // GitHub 头像 URL 格式: https://avatars.githubusercontent.com/u/xxx 或 https://github.com/identicons/xxx.png
        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            // 计算需要的像素大小（@2x 屏幕需要 2 倍）
            let pixelSize = Int(size * 2)
            // 移除现有的查询参数（如果有）
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }

    var body: some View {
        AsyncImage(url: optimizedAvatarURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            @unknown default:
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.caption)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
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

    // 共享的 URLSession，启用缓存以减少内存占用
    private static let cachedURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        // 启用缓存策略，减少重复下载
        config.requestCachePolicy = .returnCacheDataElseLoad
        // 限制缓存大小，避免占用过多内存
        config.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,  // 2MB 内存缓存
            diskCapacity: 10 * 1024 * 1024,   // 10MB 磁盘缓存
            diskPath: "StaticContributorAvatarCache"
        )
        return URLSession(configuration: config)
    }()

    /// 获取优化后的头像 URL（使用 GitHub 的缩略图参数）
    private var optimizedAvatarURL: URL? {
        guard avatar.starts(with: "http"), let url = URL(string: avatar) else { return nil }

        // 如果已经是 GitHub 头像 URL，添加大小参数
        if url.host?.contains("github.com") == true || url.host?.contains("avatars.githubusercontent.com") == true {
            // 计算需要的像素大小（@2x 屏幕需要 2 倍）
            let pixelSize = Int(size * 2)
            // 移除现有的查询参数（如果有）
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "s", value: "\(pixelSize)")]
            return components?.url
        }

        return url
    }

    var body: some View {
        Group {
            if avatar.starts(with: "http") {
                AsyncImage(url: optimizedAvatarURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.5)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    @unknown default:
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            )
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                Text(avatar)
                    .font(.system(size: 24))
                    .frame(width: size, height: size)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
}
