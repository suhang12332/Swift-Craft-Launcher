//
//  ResourceToolbarItems.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Toolbar items displayed when a resource or project is selected.
//
// Provides navigation (back), installation, and browser-open actions,
// or falls back to a data-source filter menu when no selection is active.

import SwiftUI

struct ResourceToolbarItems: View {
    @Environment(\.controlActiveState)
    private var controlActiveState
    @Environment(\.openURL)
    private var openURL
    @EnvironmentObject private var filterState: ResourceFilterState
    @EnvironmentObject private var detailState: ResourceDetailState
    @EnvironmentObject private var gameRepository: GameRepository
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @State private var showingLauncherStats = false
    @State private var launcherStatsSheetIdentity = UUID()

    /// Opens the project page for the currently loaded resource in the default browser.
    private func openCurrentResourceInBrowser() {
        guard let slug = detailState.loadedProjectDetail?.slug else { return }
        guard let id = detailState.loadedProjectDetail?.id else { return }
        let useCurseForge = detailState.gameId != nil
            ? id.starts(with: "cf-")
            : filterState.dataSource == .curseforge
        let baseURL = useCurseForge
            ? URLConfig.API.CurseForge.webProjectURL(projectType: detailState.gameResourcesType)
            : URLConfig.API.Modrinth.webProjectBase
        guard let url = URL(string: baseURL + slug) else { return }
        openURL(url)
    }

    /// Loads the full project detail and presents the install sheet.
    private func openInstallSheet() {
        guard let projectId = detailState.selectedProjectId else { return }
        let resourceType = detailState.gameResourcesType

        Task {
            if resourceType == ResourceType.modpack.rawValue {
                guard let detail = await ResourceDetailLoader.loadModPackDetail(
                    projectId: projectId,
                ) else {
                    return
                }
                await MainActor.run {
                    applyProjectDetail(
                        detail: detail,
                        projectType: ResourceType.modpack.rawValue,
                        versions: [],
                        clientSide: "",
                        serverSide: "",
                    )
                }
            } else {
                guard let result = await ResourceDetailLoader.loadProjectDetail(
                    projectId: projectId,
                    gameRepository: gameRepository,
                    resourceType: resourceType,
                ) else {
                    return
                }
                await MainActor.run {
                    applyProjectDetail(
                        detail: result.detail,
                        compatibleGames: result.compatibleGames,
                        projectType: result.detail.projectType,
                        versions: result.detail.versions,
                        clientSide: result.detail.clientSide,
                        serverSide: result.detail.serverSide,
                    )
                }
            }
        }
    }

    /// Populates the detail state with loaded project information and shows the install sheet.
    private func applyProjectDetail(
        detail: ModrinthProjectDetail,
        compatibleGames: [GameVersionInfo]? = nil,
        projectType: String,
        versions: [String],
        clientSide: String,
        serverSide: String,
    ) {
        detailState.currentProject = ModrinthProject(
            projectId: detail.id,
            projectType: projectType,
            slug: detail.slug,
            author: "",
            title: detail.title,
            description: detail.description,
            categories: detail.categories,
            displayCategories: [],
            versions: versions,
            downloads: detail.downloads,
            follows: detail.followers,
            iconUrl: detail.iconUrl,
            license: detail.license?.url ?? "",
            clientSide: clientSide,
            serverSide: serverSide,
            fileName: nil,
        )
        detailState.loadedProjectDetail = detail
        if let compatibleGames {
            detailState.compatibleGames = compatibleGames
        }
        detailState.showInstallSheet = true
    }

    var body: some View {
        Group {
            if detailState.selectedProjectId != nil {
                Button {
                    if let id = detailState.gameId {
                        detailState.selectedItem = .game(id)
                    } else {
                        detailState.selectedProjectId = nil
                        filterState.selectedTab = 0
                    }
                } label: {
                    Label("return".localized(), systemImage: "chevron.backward")
                }
                .help("return".localized())
                .id(controlActiveState)
                Spacer()
                Button {
                    openInstallSheet()
                } label: {
                    Label("resource.add".localized(), systemImage: "arrow.down.circle")
                }
                .help("resource.add".localized())
                .sheet(isPresented: detailState.showInstallSheetBinding) {
                    if let project = detailState.currentProject,
                        let detail = detailState.loadedProjectDetail {
                        if detailState.gameResourcesType == ResourceType.modpack.rawValue {
                            ModPackDownloadSheet(
                                projectId: project.projectId,
                                gameInfo: nil,
                                query: detailState.gameResourcesType,
                                preloadedDetail: detail,
                            )
                            .environmentObject(gameRepository)
                        } else {
                            GlobalResourceSheet(
                                project: project,
                                resourceType: detailState.gameResourcesType,
                                isPresented: detailState.showInstallSheetBinding,
                                preloadedDetail: detail,
                                preloadedCompatibleGames: detailState.compatibleGames,
                            )
                            .environmentObject(gameRepository)
                        }
                    }
                }
                .onChange(of: detailState.showInstallSheet) { _, newValue in
                    if !newValue {
                        detailState.compatibleGames = []
                    }
                }
                Button {
                    openCurrentResourceInBrowser()
                } label: {
                    Label("common.browser".localized(), systemImage: "safari")
                }
                .id(controlActiveState)
                .help("resource.open_in_browser".localized())
            } else {
                if detailState.gameType {
                    ResourceFilterMenus.dataSourceMenu(filterState: filterState)
                        .disabled(
                            detailState.gameResourcesType == ResourceType.minecraftJavaServer.rawValue,
                        )
                        .id(controlActiveState)
                }
            }
        }
    }
}
