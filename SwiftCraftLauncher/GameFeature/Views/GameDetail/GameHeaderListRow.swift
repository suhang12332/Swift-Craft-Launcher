import SwiftUI
import Combine

struct GameHeaderListRow: View {
    private static let iconSize: CGFloat = 80
    private static let iconPaddingRatio: CGFloat = 0.125
    private static let iconCornerRadiusRatio: CGFloat = 0.2

    let game: GameVersionInfo
    let cacheInfo: CacheInfo
    let query: String
    let onImport: () -> Void
    var onIconTap: (() -> Void)?
    private let iconRefreshNotifier: IconRefreshNotifier

    @State private var refreshTrigger: UUID = UUID()
    @State private var cancellable: AnyCancellable?

    init(
        game: GameVersionInfo,
        cacheInfo: CacheInfo,
        query: String,
        onImport: @escaping () -> Void,
        onIconTap: (() -> Void)? = nil,
        iconRefreshNotifier: IconRefreshNotifier = AppServices.iconRefreshNotifier
    ) {
        self.game = game
        self.cacheInfo = cacheInfo
        self.query = query
        self.onImport = onImport
        self.onIconTap = onIconTap
        self.iconRefreshNotifier = iconRefreshNotifier
    }

    var body: some View {
        HStack {
            gameIcon
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(game.gameName)
                        .font(.title)
                        .bold()
                        .truncationMode(.tail)
                        .lineLimit(1)
                        .frame(minWidth: 0, maxWidth: 200)
                        .fixedSize(horizontal: true, vertical: false)
                    HStack {
                        Label("\(cacheInfo.fileCount)", systemImage: "text.document")
                        Divider().frame(height: 16)
                        Label(cacheInfo.formattedSize, systemImage: "externaldrive")
                    }
                    .foregroundStyle(.secondary)
                    .font(.headline)
                    .padding(.leading, 6)
                }

                HStack(spacing: 8) {
                    Label(game.gameVersion, systemImage: "gamecontroller.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Divider().frame(height: 14)
                    Label(
                        game.modVersion.isEmpty
                            ? game.modLoader
                            : "\(game.modLoader)-\(game.modVersion)",
                        systemImage: "puzzlepiece.extension.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Divider().frame(height: 14)
                    Label(
                        game.lastPlayed.formatted(
                            .relative(presentation: .named)
                        ),
                        systemImage: "clock.fill"
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                importButton
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)
        )
    }

    /// 图标文件 URL（基础路径）
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

    /// 带刷新参数的 URL，用于绕过 AsyncImage 的缓存命中
    private var iconDisplayURL: URL? {
        guard let baseURL = iconFileURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "refresh", value: refreshTrigger.uuidString)]
        return components?.url ?? baseURL
    }

    private var gameIcon: some View {
        Group {
            if let iconURL = iconDisplayURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: Self.iconSize, height: Self.iconSize)
                    case .success(let image):
                        styledIcon(image, size: Self.iconSize)
                    case .failure:
                        defaultIcon
                    @unknown default:
                        defaultIcon
                    }
                }
                .id(refreshTrigger)
                .onDisappear {
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: iconURL)
                    )
                }
            } else {
                defaultIcon
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onIconTap?()
        }
        .onAppear {
            // 监听图标刷新通知
            cancellable = iconRefreshNotifier.refreshPublisher
                .sink { refreshedGameName in
                    // 如果通知的游戏名称匹配，或者通知为 nil（刷新所有），则刷新
                    if refreshedGameName == nil || refreshedGameName == game.gameName {
                        refreshTrigger = UUID()
                    }
                }
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .applyPointerHandIfAvailable()
    }

    private var profileDir: URL {
        AppPaths.profileDirectory(gameName: game.gameName)
    }

    private var defaultIcon: some View {
        let padding = Self.iconSize * Self.iconPaddingRatio
        let innerSize = Self.iconSize - padding * 2
        let innerCornerRadius = innerSize * Self.iconCornerRadiusRatio
        let outerCornerRadius = Self.iconSize * Self.iconCornerRadiusRatio

        return RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                Image(systemName: "photo.badge.plus")
                    .symbolRenderingMode(.multicolor)
                    .symbolVariant(.none)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .frame(width: innerSize, height: innerSize)
            .padding(padding)
            .frame(width: Self.iconSize, height: Self.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func styledIcon(_ image: Image, size: CGFloat) -> some View {
        let padding = size * Self.iconPaddingRatio // padding 为 size 的 12.5%（80 时是 10）
        let innerSize = size - padding * 2
        let innerCornerRadius = innerSize * Self.iconCornerRadiusRatio // 内层圆角为内层尺寸的 20%
        let outerCornerRadius = size * Self.iconCornerRadiusRatio // 外层圆角为外层尺寸的 20%

        image
            .resizable()
            .interpolation(.none)
            .scaledToFill()
            .frame(width: innerSize, height: innerSize)
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
            .padding(padding)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }

    private var importButton: some View {
        LocalResourceInstaller.ImportButton(
            query: query,
            gameName: game.gameName
        ) { onImport() }
    }
}
