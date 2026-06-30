//
//  CommonSheetGameBody.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A game selection picker used within resource sheets.
import SwiftUI

struct CommonSheetGameBody: View {
    let compatibleGames: [GameVersionInfo]
    @Binding var selectedGame: GameVersionInfo?

    var body: some View {
        CommonMenuPicker(
            selection: $selectedGame,
        ) {
            Text("global_resource.select_game".localized())
        } content: {
            Text("global_resource.please_select_game".localized()).tag(
                GameVersionInfo?(nil),
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
        + Text(modVersion).foregroundStyle(.secondary)
    }
}
