import SwiftUI

// MARK: - 游戏选择区块
struct CommonSheetGameBody: View {
    let compatibleGames: [GameVersionInfo]
    @Binding var selectedGame: GameVersionInfo?

    var body: some View {
        CommonMenuPicker(
            selection: $selectedGame
        ) {
            Text("global_resource.select_game".localized())
        } content: {
            Text(paddedPickerLabel("global_resource.please_select_game".localized())).tag(
                GameVersionInfo?(nil)
            )
            ForEach(compatibleGames, id: \.id) { game in
                game.displayText
                    .tag(Optional(game))
            }
        }
    }
}

extension GameVersionInfo {
    var displayText: Text {
        Text(gameName)
        + Text("-")
        + Text(gameVersion).foregroundStyle(.secondary)
        + Text("-")
        + Text(modLoader)
        + Text("-")
        + Text(paddedPickerLabel(modVersion)).foregroundStyle(.secondary)
    }
}
