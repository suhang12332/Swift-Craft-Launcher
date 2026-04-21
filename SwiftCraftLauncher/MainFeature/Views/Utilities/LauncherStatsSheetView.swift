import PlayerDataKit
import SwiftUI

struct LauncherStatsSheetView: View {
    @Environment(\.dismiss)
    private var dismiss

    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel

    @StateObject private var statsController = AllPlayersMultiGameStatsController()

    var body: some View {
        let entries = GameInstanceReportEntries.build(
            sources: gameRepository.games.map {
                GameInstanceReportSource(
                    displayName: $0.gameName,
                    profileRoot: AppPaths.profileDirectory(gameName: $0.gameName)
                )
            },
            savesDirectoryName: AppConstants.DirectoryNames.saves
        )
        CommonSheetView(
            header: {
                AllPlayersMultiGameStatsHeaderContent(controller: statsController) { uuid in
                    playerDisplayName(for: uuid)
                }
            },
            body: {
                AllPlayersMultiGameStatsReportSection(
                    controller: statsController,
                    playerDisplayName: { playerDisplayName(for: $0) },
                    playerAvatarView: { playerAvatarView(for: $0) }
                )
            },
            footer: {
                HStack {
                    Spacer()
                    Button("common.close".localized()) {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
        .frame(minWidth: 980, minHeight: 520)
        .task(id: AllPlayersMultiGameStatsController.entriesSignature(entries)) {
            await statsController.configureAndLoad(
                entries: entries,
                currentPlayerIDs: Set(playerListViewModel.players.map(\.id))
            )
        }
        .onDisappear {
            DispatchQueue.main.async {
                statsController.clearForDismiss()
            }
        }
    }

    private func launcherPlayer(for id: String) -> Player? {
        playerListViewModel.players.first {
            MinecraftPlayerIdentity.normalizedIdString($0.id) == id
        }
    }

    private func playerDisplayName(for id: String) -> String {
        launcherPlayer(for: id)?.name ?? String(id.prefix(8))
    }

    private func playerAvatarView(for id: String) -> AnyView {
        guard let player = playerListViewModel.players.first(where: {
            MinecraftPlayerIdentity.normalizedIdString($0.id) == id
        }) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            MinecraftSkinUtils(
                type: player.isRemote ? .url : .asset,
                src: player.avatarName,
                size: 32
            )
            .id(player.id)
            .id(player.avatarName)
        )
    }
}
