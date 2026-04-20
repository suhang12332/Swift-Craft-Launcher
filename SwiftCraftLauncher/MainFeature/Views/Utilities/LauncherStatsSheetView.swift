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
                        closeSheet()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        )
        .task(id: AllPlayersMultiGameStatsController.entriesSignature(entries)) {
            await statsController.configureAndLoad(entries: entries)
        }
        .onDisappear {
            statsController.clearForDismiss()
        }
    }

    private func closeSheet() {
        statsController.clearForDismiss()
        dismiss()
    }

    private func launcherPlayer(for uuid: UUID) -> Player {
        let normalizedUUID = MinecraftPlayerIdentity.normalizedIdString(uuid.uuidString)
        guard let player = playerListViewModel.players.first(where: {
            MinecraftPlayerIdentity.normalizedIdString($0.id) == normalizedUUID
        }) else {
            preconditionFailure("Launcher stats UUID must exist in player list")
        }
        return player
    }

    private func playerDisplayName(for uuid: UUID) -> String {
        launcherPlayer(for: uuid).name
    }

    private func playerAvatarView(for uuid: UUID) -> AnyView {
        let player = launcherPlayer(for: uuid)
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
