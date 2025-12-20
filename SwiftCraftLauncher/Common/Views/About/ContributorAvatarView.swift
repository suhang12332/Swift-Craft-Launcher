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

    var body: some View {
        AsyncImage(url: URL(string: avatarUrl.httpToHttps())) { phase in
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

    var body: some View {
        Group {
            if avatar.starts(with: "http") {
                AsyncImage(url: URL(string: avatar)) { phase in
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
