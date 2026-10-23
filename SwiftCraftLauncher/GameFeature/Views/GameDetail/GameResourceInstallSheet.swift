//
//  GameResourceInstallSheet.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A sheet for installing resources to a specific game with version selection and dependency handling.
import SwiftUI

struct GameResourceInstallSheet: View {
    let project: ModrinthProject
    let resourceType: String
    let gameInfo: GameVersionInfo
    @Binding var isPresented: Bool
    let preloadedDetail: ModrinthProjectDetail?
    var isUpdateMode: Bool = false

    @State private var viewModel: ResourceInstallViewModel

    init(
        project: ModrinthProject,
        resourceType: String,
        gameInfo: GameVersionInfo,
        isPresented: Binding<Bool>,
        preloadedDetail: ModrinthProjectDetail?,
        isUpdateMode: Bool = false,
        onDownloadSuccess: ((String?, String?) -> Void)? = nil,
    ) {
        self.project = project
        self.resourceType = resourceType
        self.gameInfo = gameInfo
        _isPresented = isPresented
        self.preloadedDetail = preloadedDetail
        self.isUpdateMode = isUpdateMode
        _viewModel = State(
            wrappedValue: ResourceInstallViewModel(
                project: project,
                resourceType: resourceType,
                fixedGame: gameInfo,
                configuration: .init(
                    isUpdateMode: isUpdateMode,
                    hasCompatibleGames: true,
                    dismissOnFailure: false,
                    onSuccess: onDownloadSuccess,
                ),
            ),
        )
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        return CommonSheetView(
            header: {
                Text(
                    String(
                        format: "global_resource.add_for_game".localized(),
                        gameInfo.gameName,
                    ),
                )
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
                        VersionPickerForSheet(
                            project: project,
                            resourceType: resourceType,
                            selectedGame: gameInfo,
                            selectedVersion: $viewModel.selectedVersion,
                            availableVersions: $viewModel.availableVersions,
                            isLoading: $viewModel.isLoadingVersions,
                            mainVersionId: $viewModel.mainVersionId,
                        ) { version in
                            viewModel.onVersionChanged(version)
                        }
                        if resourceType == ResourceType.mod.rawValue,
                           !isUpdateMode,
                           !viewModel.dependencyState.dependencies.isEmpty {
                            DependencySectionView(state: $viewModel.dependencyState)
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
