import SwiftUI

struct GameHeaderListRow: View {
    let game: GameVersionInfo
    let cacheInfo: CacheInfo
    let query: String
    let onImport: () -> Void
    var onIconTap: (() -> Void)?

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
            importButton
        }
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8)
        )
    }

    private var gameIcon: some View {
        Group {
            let profileDir = AppPaths.profileDirectory(gameName: game.gameName)
            let iconURL = profileDir.appendingPathComponent(game.gameIcon)
            if FileManager.default.fileExists(atPath: iconURL.path),
               let nsImage = NSImage(contentsOf: iconURL) {
                styledIcon(Image(nsImage: nsImage), size: 80)
            } else {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onIconTap?()
        }
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

    private var importButton: some View {
        LocalResourceInstaller.ImportButton(
            query: query,
            gameName: game.gameName
        ) { onImport() }
    }
}
