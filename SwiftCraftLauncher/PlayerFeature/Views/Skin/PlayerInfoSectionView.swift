import Foundation
import SwiftUI

struct PlayerInfoSectionView: View {
    let player: Player?
    @Binding var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel

    var body: some View {
        VStack(spacing: 16) {
            if let player = player {
                VStack(spacing: 12) {
                    MinecraftSkinUtils(
                        type: player.isOnlineAccount ? .url : .asset,
                        src: player.avatarName,
                        size: 88
                    )
                    Text(player.name).font(.title2.bold())

                    HStack(spacing: 4) {
                        Text("skin.classic".localized())
                            .font(.caption)
                            .foregroundColor(currentModel == .classic ? .primary : .secondary)

                        Toggle(isOn: Binding(
                            get: { currentModel == .slim },
                            set: { currentModel = $0 ? .slim : .classic }
                        )) {
                            EmptyView()
                        }
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)

                        Text("skin.slim".localized())
                            .font(.caption)
                            .foregroundColor(currentModel == .slim ? .primary : .secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "skin.no_player".localized(),
                    systemImage: "person",
                    description: Text("skin.add_player_first".localized())
                )
            }
        }.frame(width: 280)
    }
}
