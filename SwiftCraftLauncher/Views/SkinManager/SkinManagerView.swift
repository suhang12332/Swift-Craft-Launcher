import SwiftUI
import UniformTypeIdentifiers

public struct SkinManagerView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var skinSelection: SkinSelectionStore

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only show current player if it's an online account
            if let current = playerListViewModel.currentPlayer, current.isOnlineAccount {
                Section {
                    HStack(spacing: 12) {
                        MinecraftSkinUtils(type: .url, src: current.avatarName, size: 64)
                            .id(current.id)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(current.name).font(.headline)
                            Text("Online Account").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                } header: {
                    Text("Current Player")
                }
            }

            let onlinePlayers = playerListViewModel.players.filter { $0.isOnlineAccount }
            Section {
                if onlinePlayers.isEmpty {
                    ContentUnavailableView("No Microsoft Accounts", systemImage: "person.badge.key", description: Text("Please sign in with a Microsoft account"))
                } else {
                    ForEach(onlinePlayers) { player in
                        VStack(spacing: 0) {
                            Button {
                                skinSelection.select(player.id)
                            } label: {
                                HStack(spacing: 12) {
                                    MinecraftSkinUtils(type: .url, src: player.avatarName, size: 40)
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
                Text("Microsoft Accounts")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .onChange(of: playerListViewModel.players) { _, _ in
            let online = playerListViewModel.players.filter { $0.isOnlineAccount }
            if let selected = skinSelection.selectedPlayerId, !online.contains(where: { $0.id == selected }) {
                skinSelection.select(online.first?.id)
            } else if skinSelection.selectedPlayerId == nil {
                skinSelection.select(online.first?.id)
            }
        }
        .onAppear {
            let online = playerListViewModel.players.filter { $0.isOnlineAccount }
            if skinSelection.selectedPlayerId == nil {
                skinSelection.select(online.first?.id)
            }
        }
    }
}

#Preview {
    SkinManagerView()
        .environmentObject(PlayerListViewModel())
}
