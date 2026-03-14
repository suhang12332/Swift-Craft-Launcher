//
//  ResourceToolbarItems.swift
//  SwiftCraftLauncher
//

import SwiftUI

/// 选中资源/项目时的详情工具栏内容：返回、安装、在浏览器打开，或仅数据源菜单
struct ResourceToolbarItems: View {
    @Environment(\.openURL)
    private var openURL
    @EnvironmentObject var filterState: ResourceFilterState
    @EnvironmentObject var detailState: ResourceDetailState
    @EnvironmentObject var gameRepository: GameRepository

    /// 打开当前资源在浏览器中的项目页面
    private func openCurrentResourceInBrowser() {
        guard let slug = detailState.loadedProjectDetail?.slug else { return }

        let baseURL: String = switch filterState.dataSource {
        case .modrinth:
            URLConfig.API.Modrinth.webProjectBase
        case .curseforge:
            URLConfig.API.CurseForge.webProjectURL(projectType: detailState.gameResourcesType)
        }

        guard let url = URL(string: baseURL + slug) else { return }
        openURL(url)
    }

    private func openInstallSheet() {
        guard let projectId = detailState.selectedProjectId else { return }
        let resourceType = detailState.gameResourcesType

        Task {
            if resourceType == "modpack" {
                guard let detail = await ResourceDetailLoader.loadModPackDetail(
                    projectId: projectId
                ) else {
                    return
                }
                await MainActor.run {
                    applyProjectDetail(
                        detail: detail,
                        projectType: "modpack",
                        versions: [],
                        clientSide: "",
                        serverSide: ""
                    )
                }
            } else {
                guard let result = await ResourceDetailLoader.loadProjectDetail(
                    projectId: projectId,
                    gameRepository: gameRepository,
                    resourceType: resourceType
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
                        serverSide: result.detail.serverSide
                    )
                }
            }
        }
    }

    private func applyProjectDetail(
        detail: ModrinthProjectDetail,
        compatibleGames: [GameVersionInfo]? = nil,
        projectType: String,
        versions: [String],
        clientSide: String,
        serverSide: String
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
            fileName: nil
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
                    Label("return".localized(), systemImage: "arrow.backward")
                }
                .help("return".localized())
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
                        if detailState.gameResourcesType == "modpack" {
                            ModPackDownloadSheet(
                                projectId: project.projectId,
                                gameInfo: nil,
                                query: detailState.gameResourcesType,
                                preloadedDetail: detail
                            )
                            .environmentObject(gameRepository)
                        } else {
                            GlobalResourceSheet(
                                project: project,
                                resourceType: detailState.gameResourcesType,
                                isPresented: detailState.showInstallSheetBinding,
                                preloadedDetail: detail,
                                preloadedCompatibleGames: detailState.compatibleGames
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
                .help("resource.open_in_browser".localized())
            } else {
                if detailState.gameType {
                    ResourceFilterMenus.dataSourceMenu(filterState: filterState)
                }
            }
        }
    }
}
