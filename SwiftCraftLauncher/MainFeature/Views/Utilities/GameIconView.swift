import SwiftUI

/// 游戏图标视图组件，支持图标刷新
struct GameIconView: View {
    let game: GameVersionInfo
    let refreshTrigger: UUID

    private var iconFileURL: URL? {
        let trimmed = game.gameIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = profileDir.appendingPathComponent(trimmed)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else { return nil }

        return url
    }

    /// 获取图标URL（添加刷新触发器作为查询参数，强制AsyncImage重新加载）
    private var iconURL: URL {
        guard let baseURL = iconFileURL else { return profileDir }
        // 添加刷新触发器作为查询参数，确保文件更新后能重新加载
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "refresh", value: refreshTrigger.uuidString)]
        return components?.url ?? baseURL
    }

    var body: some View {
        Group {
            if iconFileURL != nil {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.mini)
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    case .failure:
                        iconPlaceholder
                    @unknown default:
                        EmptyView()
                    }
                }
                .onDisappear {
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: iconURL)
                    )
                }
            } else {
                iconPlaceholder
            }
        }
        .frame(width: 20, height: 20, alignment: .center)
    }

    private var profileDir: URL {
        AppPaths.profileDirectory(gameName: game.gameName)
    }

    private var iconPlaceholder: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                Image(systemName: "photo.badge.plus")
                    .symbolRenderingMode(.multicolor)
                    .symbolVariant(.none)
                    .font(.system(size: 6, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(width: 16, height: 16)
    }
}
