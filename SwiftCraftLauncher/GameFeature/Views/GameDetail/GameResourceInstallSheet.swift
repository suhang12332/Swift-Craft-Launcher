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
    @EnvironmentObject private var gameRepository: GameRepository
    /// Invoked on successful download with (fileName, hash). Nil values for manual downloads.
    var onDownloadSuccess: ((String?, String?) -> Void)?

    @StateObject private var viewModel: GameResourceInstallSheetViewModel

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
        self.onDownloadSuccess = onDownloadSuccess
        _viewModel = StateObject(
            wrappedValue: GameResourceInstallSheetViewModel(
                project: project,
                resourceType: resourceType,
                gameInfo: gameInfo,
                isUpdateMode: isUpdateMode,
            ),
        )
    }

    var body: some View {
        CommonSheetView(
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
                            selectedGame: .constant(gameInfo),
                            selectedVersion: $viewModel.selectedVersion,
                            availableVersions: $viewModel.availableVersions,
                            mainVersionId: $viewModel.mainVersionId,
                        ) { version in
                            viewModel.onVersionChanged(version)
                        }
                        if resourceType == ResourceType.mod.rawValue, !isUpdateMode {
                            if viewModel.dependencyState.isLoading
                                || !viewModel.dependencyState.dependencies.isEmpty {
                                DependencySectionView(state: $viewModel.dependencyState)
                            }
                        }
                    }
                }
            },
            footer: {
                GameResourceInstallFooter(
                    isPresented: $isPresented,
                    projectDetail: preloadedDetail,
                    viewModel: viewModel,
                    onDownloadSuccess: onDownloadSuccess,
                )
            },
        )
        .onAppear { viewModel.setDependencies(gameRepository: gameRepository) }
        .onDisappear { viewModel.cleanup() }
    }
}

/// Footer with download action buttons for the resource install sheet.
struct GameResourceInstallFooter: View {
    @Binding var isPresented: Bool
    let projectDetail: ModrinthProjectDetail?
    @ObservedObject var viewModel: GameResourceInstallSheetViewModel
    /// Invoked on successful download with (fileName, hash). Nil values for manual downloads.
    var onDownloadSuccess: ((String?, String?) -> Void)?

    var body: some View {
        Group {
            if projectDetail != nil {
                HStack {
                    Button("common.close".localized()) { isPresented = false }
                    Spacer()
                    if viewModel.resourceType == ResourceType.mod.rawValue,
                        !viewModel.isUpdateMode {
                        if !viewModel.dependencyState.isLoading {
                            if viewModel.selectedVersion != nil {
                                Button {
                                    viewModel.downloadAllManual(
                                        onSuccess: { fileName, hash in
                                            onDownloadSuccess?(fileName, hash)
                                        },
                                        dismiss: { isPresented = false },
                                    )
                                } label: {
                                    if viewModel.isDownloadingAll {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Text(
                                            "global_resource.download_all"
                                                .localized(),
                                        )
                                    }
                                }
                                .disabled(viewModel.isDownloadingAll)
                                .keyboardShortcut(.defaultAction)
                            }
                        }
                    } else {
                        if viewModel.selectedVersion != nil {
                            Button {
                                viewModel.downloadResource(
                                    onSuccess: { fileName, hash in
                                        onDownloadSuccess?(fileName, hash)
                                    },
                                    dismiss: { isPresented = false },
                                )
                            } label: {
                                if viewModel.isDownloadingAll {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("global_resource.download".localized())
                                }
                            }
                            .disabled(viewModel.isDownloadingAll)
                            .keyboardShortcut(.defaultAction)
                        }
                    }
                }
            } else {
                HStack {
                    Spacer()
                    Button("common.close".localized()) { isPresented = false }
                }
            }
        }
    }
}
