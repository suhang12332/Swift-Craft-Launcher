import SwiftUI

/// 通用侧边栏视图组件，用于显示游戏列表和资源列表的导航
public struct SidebarView: View {
    @Binding var selectedItem: SidebarItem
    @State private var showingGameForm = false
    @State private var showPlayerAlert = false
    @EnvironmentObject var gameRepository: GameRepository
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @State private var searchText: String = ""
    
    public init(selectedItem: Binding<SidebarItem>) {
        self._selectedItem = selectedItem
    }
    
    public var body: some View {
        List(selection: $selectedItem) {
            // 资源部分
            Section(header: Text("sidebar.resources.title".localized())) {
                ForEach(ResourceType.allCases, id: \.self) { type in
                    NavigationLink(value: SidebarItem.resource(type)) {
                        Text(type.localizedName)
                    }
                }
            }
            
            // 游戏部分
            Section(header: Text("sidebar.games.title".localized())) {
                ForEach(filteredGames) { game in
                    NavigationLink(value: SidebarItem.game(game.id)) {
                        HStack(spacing: 6) {
                            if let iconURL = AppPaths.profileDirectory(gameName: game.gameName)?.appendingPathComponent(game.gameIcon),
                               FileManager.default.fileExists(atPath: iconURL.path) {
                                AsyncImage(url: iconURL) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    case .failure:
                                    Image("default_game_icon")
                                        .resizable()
                                        .interpolation(.none)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            } else {
                                Image("default_game_icon")
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Text(game.gameName)
                                .lineLimit(1)
                        }
                        .tag(game.id)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "sidebar.search.games".localized())
        .safeAreaInset(edge: .bottom) {
            Button(action: {
                if playerListViewModel.currentPlayer == nil {
                    showPlayerAlert = true
                } else {
                    showingGameForm.toggle()
                }
            }) {
                Label("game.form.title".localized(), systemImage: "gamecontroller")
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showingGameForm) {
            GameFormView()
                .environmentObject(gameRepository)
                .environmentObject(playerListViewModel)
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.automatic)
        }
        .alert(isPresented: $showPlayerAlert) {
            Alert(
                title: Text("sidebar.alert.no_player.title".localized()),
                message: Text("sidebar.alert.no_player.message".localized()),
                dismissButton: .default(Text("common.confirm".localized()))
            )
        }
    

    }
    
    // 只对游戏名做模糊搜索
    private var filteredGames: [GameVersionInfo] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return gameRepository.games
        }
        let lower = searchText.lowercased()
        return gameRepository.games.filter { $0.gameName.lowercased().contains(lower) }
    }
}
