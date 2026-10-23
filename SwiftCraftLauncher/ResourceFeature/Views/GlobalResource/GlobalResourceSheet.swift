//
//  GlobalResourceSheet.swift
//  ResourceFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A sheet for adding or downloading a project resource with version and dependency selection.
struct GlobalResourceSheet: View {
    let project: ModrinthProject
    let resourceType: String
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?
    let preloadedCompatibleGames: [GameVersionInfo]

    @State private var viewModel: ResourceInstallViewModel

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
        _viewModel = State(
            wrappedValue: ResourceInstallViewModel(
                project: project,
                resourceType: resourceType,
                fixedGame: nil,
                configuration: .init(
                    hasCompatibleGames: !preloadedCompatibleGames.isEmpty,
                    dismissOnFailure: true,
                ),
            ),
        )
    }

    /// Sheet title that changes based on resource type and game selection.
    private var headerTitle: String {
        let isServer = resourceType == ResourceType.minecraftJavaServer.rawValue
        let baseKey = isServer ? "saveinfo.server.add" : "global_resource.add"
        let forGameKey = isServer ? "saveinfo.server.add_for_game" : "global_resource.add_for_game"

        if let game = viewModel.selectedGame {
            return String(format: forGameKey.localized(), game.gameName)
        } else {
            return baseKey.localized()
        }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return CommonSheetView(
            header: {
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            body: {
                if let detail = preloadedDetail {
                    VStack {
                        ModrinthProjectTitleView(
                            projectDetail: detail,
                        ).padding(.bottom, 18)

                        Text("settings.game.tab".localized())
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        CommonSheetGameBody(
                            compatibleGames: preloadedCompatibleGames,
                            selectedGame: $viewModel.selectedGame,
                        )
                        if let game = viewModel.selectedGame {
                            if resourceType != ResourceType.minecraftJavaServer.rawValue {
                                spacerView()
                                VersionPickerForSheet(
                                    project: project,
                                    resourceType: resourceType,
                                    selectedGame: game,
                                    selectedVersion: $viewModel.selectedVersion,
                                    availableVersions: $viewModel.availableVersions,
                                    isLoading: $viewModel.isLoadingVersions,
                                    mainVersionId: $viewModel.mainVersionId,
                                ) { version in
                                    viewModel.onVersionChanged(version)
                                }
                                if resourceType == ResourceType.mod.rawValue,
                                   !viewModel.dependencyState.dependencies.isEmpty {
                                    DependencySectionView(state: $viewModel.dependencyState)
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                ResourceInstallFooterView(
                    projectDetail: preloadedDetail,
                    viewModel: viewModel,
                    isPresented: $isPresented,
                )
            },
        )
        .onDisappear {
            viewModel.cleanup()
        }
    }
}
