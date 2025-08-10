//
//  GameInfoDetailView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/6/2.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Window Delegate
// 已移除 NSWindowDelegate 相关代码，纯 SwiftUI 不再需要

// MARK: - Views
struct GameInfoDetailView: View {
    let game: GameVersionInfo

    @Binding var query: String
    @Binding var currentPage: Int
    @Binding var totalItems: Int
    @Binding var sortIndex: String
    @Binding var selectedVersions: [String]
    @Binding var selectedCategories: [String]
    @Binding var selectedFeatures: [String]
    @Binding var selectedResolutions: [String]
    @Binding var selectedPerformanceImpact: [String]
    @Binding var selectedProjectId: String?
    @Binding var selectedLoaders: [String]
    @Binding var gameType: Bool  // false = local, true = server
    @EnvironmentObject var gameRepository: GameRepository
    @State private var searchTextForResource = ""
    @State private var showDeleteAlert = false
    @Binding var selectedItem: SidebarItem
    @State private var scannedResources: [ModrinthProjectDetail] = []
    @State private var isLoadingResources = false
    @State private var showImporter = false
    @State private var importErrorMessage: String?
    @StateObject private var cacheManager = CacheManager()
    @State private var error: GlobalError?
    
    var body: some View {
        return VStack {
            headerView
            Divider().padding(.top, 4)
            if gameType {
                ModrinthDetailView(
                    query: query,
                    currentPage: $currentPage,
                    totalItems: $totalItems,
                    sortIndex: $sortIndex,
                    selectedVersions: $selectedVersions,
                    selectedCategories: $selectedCategories,
                    selectedFeatures: $selectedFeatures,
                    selectedResolutions: $selectedResolutions,
                    selectedPerformanceImpact: $selectedPerformanceImpact,
                    selectedProjectId: $selectedProjectId,
                    selectedLoader: $selectedLoaders,
                    gameInfo: game,
                    selectedItem: $selectedItem,
                    gameType: $gameType
                )
            } else {
                localResourceList
            }
        }
        .onChange(of: game.gameName) {
            cacheManager.calculateGameCacheInfo(game.gameName)
            scanResources()
        }
        .onChange(of: gameType) {
            scanResources()
        }
        .onChange(of: query) {
            scanResources()
        }
        .onAppear {
            cacheManager.calculateGameCacheInfo(game.gameName)
        }
        .alert("error.notification.validation.title".localized(), isPresented: .constant(error != nil)) {
            Button("common.close".localized()) {
                error = nil
            }
        } message: {
            if let error = error {
                Text(error.chineseMessage)
            }
        }
        
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            gameIcon
            VStack(alignment: .leading, spacing: 4) {
                HStack{
                    Text(game.gameName)
                        .font(.title)
                        .bold()
                    HStack {
                        Label("\(cacheManager.cacheInfo.fileCount)",systemImage: "text.document")
                        Divider().frame(height: 16)
                        Label(cacheManager.cacheInfo.formattedSize, systemImage: "externaldrive")
                        
                    }.foregroundStyle(.secondary).font(.headline).padding(.leading,6)
                }
                
                HStack(spacing: 8) {
                    Label(game.gameVersion, systemImage: "gamecontroller.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Divider().frame(height: 14)
                    Label(
                        game.modVersion.isEmpty ? game.modLoader : game.modLoader + "-" + game.modVersion,
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
            deleteButton
        }
    }

    private var gameIcon: some View {
        Group {
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
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                    case .failure:
                        Image("default_game_icon")
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Image("default_game_icon")
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
            }
        }
    }

    private var deleteButton: some View {
        Button(action: { showDeleteAlert = true }) {
//            Image(systemName: "trash.fill")
            Text("common.delete".localized()).font(.subheadline)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentColor)
        .controlSize(.large)
        .confirmationDialog(
            "delete.title".localized(),
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("common.delete".localized(), role: .destructive) {
                deleteGameAndProfile()
            }
            .keyboardShortcut(.defaultAction)
            Button("common.cancel".localized(), role: .cancel) {}
        } message: {
            Text(String(format: "delete.game.confirm".localized(), game.gameName))
        }
    }

    private var importButton: some View {
        LocalResourceInstaller.ImportButton(
            query: query,
            gameName: game.gameName,
            onResourceChanged: { scanResources() }
        )
    }

    private var localResourceList: some View {
        VStack {
            if isLoadingResources {
                ProgressView()
                    .padding()
            } else {
                let filteredResources = scannedResources.filter { res in
                    (searchTextForResource.isEmpty
                        || res.title.localizedCaseInsensitiveContains(
                            searchTextForResource
                        ))
                }.map { ModrinthProject.from(detail: $0) }
                ForEach(filteredResources, id: \.projectId) { mod in
                    // todo mod的作者需要修改或者不显示
                    ModrinthDetailCardView(
                        project: mod,
                        selectedVersions: [game.gameVersion],
                        selectedLoaders: [game.modLoader],
                        gameInfo: game,
                        query: query,
                        type: gameType,
                        selectedItem: $selectedItem,
                        onResourceChanged: {
                            scanResources()
                        }
                    )
                    .padding(.vertical, ModrinthConstants.UI.verticalPadding)
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
                    )
                    .onTapGesture {
                        selectedProjectId = mod.projectId
                        if let type = ResourceType(rawValue: query) {
                            selectedItem = .resource(type)
                        }
                    }
                }
            }
        }
        .searchable(
            text: $searchTextForResource,
            placement: .toolbar,
            prompt: "searh.resources".localized()
        )
    }

    private func scanResources() {
        guard !isLoadingResources else { return }
        isLoadingResources = true
        guard
            let resourceDir = AppPaths.resourceDirectory(
                for: query,
                gameName: game.gameName
            )
        else {
            let globalError = GlobalError.configuration(
                chineseMessage: "无法获取资源目录路径",
                i18nKey: "error.configuration.resource_directory_not_found",
                level: .notification
            )
            Logger.shared.error("扫描资源失败: \(globalError.chineseMessage)")
            GlobalErrorHandler.shared.handle(globalError)
            error = globalError
            scannedResources = []
            isLoadingResources = false
            return
        }
        ModScanner.shared.scanResourceDirectory(resourceDir) { details in
            scannedResources = details
            isLoadingResources = false
        }
    }

    // MARK: - 删除游戏及其文件夹
    private func deleteGameAndProfile() {
        Task {
            do {
                // 先切换到其他游戏或资源页面，避免删除后页面重新加载
                await MainActor.run {
                    if let firstGame = gameRepository.games.first(where: { $0.id != game.id }) {
                        selectedItem = .game(firstGame.id)
                    } else {
                        selectedItem = .resource(.mod)
                    }
                }
                
                // 先删除游戏文件夹
                if let profileDir = AppPaths.profileDirectory(gameName: game.gameName) {
                    try FileManager.default.removeItem(at: profileDir)
                }
                
                // 然后删除游戏记录
                try await gameRepository.deleteGame(id: game.id)
                
                Logger.shared.info("成功删除游戏: \(game.gameName)")
            } catch {
                let globalError = GlobalError.fileSystem(
                    chineseMessage: "删除游戏失败: \(error.localizedDescription)",
                    i18nKey: "error.filesystem.game_deletion_failed",
                    level: .notification
                )
                Logger.shared.error("删除游戏失败: \(globalError.chineseMessage)")
                GlobalErrorHandler.shared.handle(globalError)
                await MainActor.run {
                    self.error = globalError
                }
            }
        }
    }

}
