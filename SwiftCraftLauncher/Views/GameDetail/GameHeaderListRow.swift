import SwiftUI
import Combine

struct GameHeaderListRow: View {
    let game: GameVersionInfo
    let cacheInfo: CacheInfo
    let query: String
    let onImport: () -> Void
    var onIconTap: (() -> Void)?

    @State private var refreshTrigger: UUID = UUID()
    @State private var cancellable: AnyCancellable?

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
                exportButton
                importButton
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)
        )
    }

    /// 获取图标URL（添加刷新触发器作为查询参数，强制AsyncImage重新加载）
    private var iconURL: URL {
        let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
        let baseURL = profileDir.appendingPathComponent(game.gameIcon)
        // 添加刷新触发器作为查询参数，确保文件更新后能重新加载
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "refresh", value: refreshTrigger.uuidString)]
        return components?.url ?? baseURL
    }

    private var gameIcon: some View {
        AsyncImage(url: iconURL) { phase in
            switch phase {
            case .empty:
                defaultIcon
            case .success(let image):
                styledIcon(image, size: 80)
            case .failure:
                defaultIcon
            @unknown default:
                defaultIcon
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onIconTap?()
        }
        .onAppear {
            // 监听图标刷新通知
            cancellable = IconRefreshNotifier.shared.refreshPublisher
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
    }

    private var defaultIcon: some View {
        Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
            .resizable()
            .interpolation(.none)
            .frame(width: 80, height: 80)
            .cornerRadius(16)
    }

    @ViewBuilder
    private func styledIcon(_ image: Image, size: Int) -> some View {
        let padding: CGFloat = CGFloat(size) * 0.125 // padding 为 size 的 12.5%（80 时是 10）
        let innerSize = CGFloat(size) - padding * 2
        let innerCornerRadius = innerSize * 0.2 // 内层圆角为内层尺寸的 20%
        let outerCornerRadius = CGFloat(size) * 0.2 // 外层圆角为外层尺寸的 20%

        image
            .resizable()
            .interpolation(.none)
            .scaledToFill()
            .frame(width: innerSize, height: innerSize)
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
            .padding(padding)
            .frame(width: CGFloat(size), height: CGFloat(size))
            .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }

    @State private var showExportSheet = false

    private var exportButton: some View {
        Button {
            showExportSheet = true
        } label: {
            Label("modpack.export.button".localized(), systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showExportSheet) {
            ModPackExportSheet(gameInfo: game)
        }
    }

    private var importButton: some View {
        LocalResourceInstaller.ImportButton(
            query: query,
            gameName: game.gameName
        ) { onImport() }
    }
}
