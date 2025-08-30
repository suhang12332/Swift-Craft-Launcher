import SwiftUI
import UniformTypeIdentifiers

public struct SkinManagerView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var skinSelection: SkinSelectionStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let current = playerListViewModel.currentPlayer {
                Section {
                    HStack(spacing: 12) {
                        MinecraftSkinUtils(type: current.isOnlineAccount ? .url : .asset, src: current.avatarName, size: 64)
                            .id(current.id)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.name).font(.headline)
                            Text(current.isOnlineAccount ? "Online Account" : "Offline Account").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } header: {
                    Text("Current Player")
                }
            }

            Section {
                if playerListViewModel.players.isEmpty {
                    ContentUnavailableView("No Players", systemImage: "person", description: Text("Please add players before managing skins"))
                } else {
                    ForEach(playerListViewModel.players) { player in
                        VStack(spacing: 0) {
                            Button {
                                skinSelection.select(player.id)
                            } label: {
                                HStack(spacing: 12) {
                                    MinecraftSkinUtils(type: player.isOnlineAccount ? .url : .asset, src: player.avatarName, size: 40)
                                        .id(player.id)
                                    Text(player.name)
                                    Spacer()
                                    if playerListViewModel.currentPlayer?.id == player.id {
                                        Text("Current").font(.caption2).padding(4).background(Color.accentColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(skinSelection.selectedPlayerId == player.id ? Color.accentColor.opacity(0.15) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            } header: {
                Text("All Players")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SkinManagerView()
        .environmentObject(PlayerListViewModel())
}
