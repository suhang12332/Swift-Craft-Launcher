//
//  GlobalResourceSheet.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A sheet for adding or downloading a project resource with version and dependency selection.
struct GlobalResourceSheet: View {
    @EnvironmentObject private var container: DIContainer
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?
    let preloadedCompatibleGames: [GameVersionInfo]
    @EnvironmentObject private var gameRepository: GameRepository
    @State private var selectedGame: GameVersionInfo?
    @State private var selectedVersion: ModrinthProjectDetailVersion?
    @State private var availableVersions: [ModrinthProjectDetailVersion] = []
    @State private var dependencyState = DependencyState()
    @State private var isDownloadingAll = false
    @State private var isDownloadingMainOnly = false
    @State private var mainVersionId = ""

    init(
        project: ModrinthProject,
        resourceType: String,
        isPresented: Binding<Bool>,
        preloadedDetail: ModrinthProjectDetail?,
        preloadedCompatibleGames: [GameVersionInfo],
    ) {
        self.project = project
        self.resourceType = resourceType
        _isPresented = isPresented
        self.preloadedDetail = preloadedDetail
        self.preloadedCompatibleGames = preloadedCompatibleGames
    }

    /// Sheet title that changes based on resource type and game selection.
    private var headerTitle: String {
        let isServer = resourceType == ResourceType.minecraftJavaServer.rawValue
        let baseKey = isServer ? "saveinfo.server.add" : "global_resource.add"
        let forGameKey = isServer ? "saveinfo.server.add_for_game" : "global_resource.add_for_game"

        if let game = selectedGame {
            return String(format: forGameKey.localized(), game.gameName)
        } else {
            return baseKey.localized()
        }
    }

    var body: some View {
        CommonSheetView(
            header: {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if let detail = preloadedDetail {
                    if preloadedCompatibleGames.isEmpty {
                        Text("global_resource.no_game_list".localized())
                            .foregroundColor(.secondary).padding()
                    } else {
                        VStack {
                            ModrinthProjectTitleView(
                                projectDetail: detail,
                            ).padding(.bottom, 18)
                            CommonSheetGameBody(
                                compatibleGames: preloadedCompatibleGames,
                                selectedGame: $selectedGame,
                            )
                            if let game = selectedGame {
                                if resourceType != ResourceType.minecraftJavaServer.rawValue {
                                    spacerView()
                                    VersionPickerForSheet(
                                        project: project,
                                        resourceType: resourceType,
                                        selectedGame: $selectedGame,
                                        selectedVersion: $selectedVersion,
                                        availableVersions: $availableVersions,
                                        mainVersionId: $mainVersionId,
                                    ) { version in
                                        if resourceType == ResourceType.mod.rawValue,
                                           let v = version {
                                            loadDependencies(for: v, game: game)
                                        } else {
                                            dependencyState = DependencyState()
                                        }
                                    }
                                    if resourceType == ResourceType.mod.rawValue {
                                        if dependencyState.isLoading || !dependencyState.dependencies.isEmpty {
                                            DependencySectionView(state: $dependencyState)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                GlobalResourceFooter(
                    project: project,
                    resourceType: resourceType,
                    isPresented: $isPresented,
                    projectDetail: preloadedDetail,
                    selectedGame: selectedGame,
                    selectedVersion: selectedVersion,
                    dependencyState: dependencyState,
                    isDownloadingAll: $isDownloadingAll,
                    isDownloadingMainOnly: $isDownloadingMainOnly,
                    gameRepository: gameRepository,
                    loadDependencies: loadDependencies,
                    mainVersionId: $mainVersionId,
                    compatibleGames: preloadedCompatibleGames,
                )
            },
        )
        .onDisappear {
            selectedGame = nil
            selectedVersion = nil
            availableVersions = []
            dependencyState = DependencyState()
            isDownloadingAll = false
            isDownloadingMainOnly = false
            mainVersionId = ""
        }
    }

    private func loadDependencies(
        for version: ModrinthProjectDetailVersion,
        game: GameVersionInfo,
    ) {
        dependencyState.isLoading = true
        Task {
            do {
                try await loadDependenciesThrowing(for: version, game: game)
            } catch {
                let globalError = GlobalError.from(error)
                AppLog.resource.error("Failed to load dependencies: \(globalError.localizedDescription)")
                container.core.errorHandler.handle(globalError)
                _ = await MainActor.run {
                    dependencyState = DependencyState()
                }
            }
        }
    }

    private func loadDependenciesThrowing(
        for _: ModrinthProjectDetailVersion,
        game: GameVersionInfo,
    ) async throws {
        guard !project.projectId.isEmpty else {
            throw GlobalError.validation(
                i18nKey: "error.validation.project_id_empty",
                level: .notification,
                message: "project.projectId is empty for project '\(project.title)'",
            )
        }

        // Fetch missing dependencies with version information.
        let missingWithVersions =
            await ModrinthDependencyDownloader
                .getMissingDependenciesWithVersions(
                    for: project.projectId,
                    gameInfo: game,
                )

        var depVersions: [String: [ModrinthProjectDetailVersion]] = [:]
        var depSelected: [String: ModrinthProjectDetailVersion?] = [:]
        var dependencies: [ModrinthProjectDetail] = []

        for (detail, versions) in missingWithVersions {
            dependencies.append(detail)
            depVersions[detail.id] = versions
            depSelected[detail.id] = versions.first
        }

        _ = await MainActor.run {
            dependencyState = DependencyState(
                dependencies: dependencies,
                versions: depVersions,
                selected: depSelected,
                isLoading: false,
            )
        }
    }
}
