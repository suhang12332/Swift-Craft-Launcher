//
//  ModPackDownloadSheet.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// A sheet for downloading and installing a modpack from a remote project.
struct ModPackDownloadSheet: View {
    let projectId: String
    let gameInfo: GameVersionInfo?
    let query: String
    let preloadedDetail: ModrinthProjectDetail?
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel = ModPackDownloadSheetViewModel()
    @State private var coordinator = ModPackDownloadSheetCoordinatorViewModel()
    @State private var selectedGameVersion: String = ""
    @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
    @State private var gameSetupService = GameSetupUtil()
    @State private var gameNameValidator: GameNameValidator

    init(
        projectId: String,
        gameInfo: GameVersionInfo?,
        query: String,
        preloadedDetail: ModrinthProjectDetail? = nil,
    ) {
        self.projectId = projectId
        self.gameInfo = gameInfo
        self.query = query
        self.preloadedDetail = preloadedDetail
        _gameNameValidator = State(wrappedValue: GameNameValidator(gameSetupService: GameSetupUtil()))
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView },
        )
        .onAppear {
            coordinator.onAppear(
                sheetViewModel: viewModel,
                gameRepository: gameRepository,
                projectId: projectId,
                preloadedDetail: preloadedDetail,
            )
        }
        .onDisappear {
            clearAllData()
        }
    }

    private func clearAllData() {
        selectedGameVersion = ""
        selectedModPackVersion = nil
        coordinator.onDisappear(
            sheetViewModel: viewModel,
            gameSetupService: gameSetupService,
        )
    }

    private var headerView: some View {
        Text("modpack.download.title".localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isProcessing {
                DownloadingProgressView(
                    progress: viewModel.modPackDownloadProgress,
                    totalSize: viewModel.modPackTotalSize,
                    title: "modpack.processing.title".localized(),
                    subtitle: "modpack.processing.subtitle.remote".localized(),
                )
            } else if viewModel.isLoadingProjectDetails {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else if let projectDetail = viewModel.projectDetail {
                ModrinthProjectTitleView(projectDetail: projectDetail)
                    .padding(.bottom, 18)

                VersionSelectionView(
                    selectedGameVersion: $selectedGameVersion,
                    selectedModPackVersion: $selectedModPackVersion,
                    availableGameVersions: viewModel.availableGameVersions,
                    filteredModPackVersions: viewModel.filteredModPackVersions,
                    isLoadingModPackVersions: viewModel.isLoadingModPackVersions,
                    isProcessing: viewModel.isProcessing,
                    onGameVersionChange: handleGameVersionChange,
                    onModPackVersionAppear: selectFirstModPackVersion,
                )

                if !selectedGameVersion.isEmpty, selectedModPackVersion != nil {
                    ModPackInstallSharedSections(
                        gameName: $gameNameValidator.gameName,
                        isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                        isGameNameInputDisabled: viewModel.isProcessing,
                        showGameNameInput: true,
                        gameSetupService: gameSetupService,
                        modPackInstallState: viewModel.modPackInstallState,
                        lastParsedIndexInfo: viewModel.lastParsedIndexInfo,
                        shouldShowProgress: shouldShowProgress,
                    )
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            cancelButton
            Spacer()
            confirmButton
        }
    }

    private var shouldShowProgress: Bool {
        gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var canDownload: Bool {
        !selectedGameVersion.isEmpty && selectedModPackVersion != nil && gameNameValidator.isFormValid
    }

    private var isDownloading: Bool {
        viewModel.isProcessing || gameSetupService.downloadState.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var cancelButton: some View {
        Button(isDownloading ? "common.stop".localized() : "common.cancel".localized()) {
            handleCancel()
        }
        .keyboardShortcut(.cancelAction)
    }

    private var confirmButton: some View {
        Button {
            Task {
                await startDownload()
            }
        } label: {
            HStack {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("global_resource.download".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canDownload || isDownloading)
    }

    private func handleGameVersionChange(_ newValue: String) {
        if !newValue.isEmpty {
            Task {
                await viewModel.loadModPackVersions(for: newValue)
            }
            setDefaultGameName()
        } else {
            viewModel.filteredModPackVersions = []
        }
    }

    private func selectFirstModPackVersion() {
        if !viewModel.filteredModPackVersions.isEmpty,
           selectedModPackVersion == nil {
            selectedModPackVersion = viewModel.filteredModPackVersions[0]
            setDefaultGameName()
        }
    }

    private func setDefaultGameName() {
        let defaultName = GameNameGenerator.generateModPackName(
            projectTitle: viewModel.projectDetail?.title,
            gameVersion: selectedGameVersion,
            includeTimestamp: true,
        )
        gameNameValidator.setDefaultName(defaultName)
    }

    private func handleCancel() {
        if isDownloading {
            Task {
                viewModel.cancelDownloadAndResetStates(gameSetupService: gameSetupService)
                await viewModel.cleanupGameDirectoriesForCancel(gameName: gameNameValidator.gameName)
            }
            dismiss()
        } else {
            dismiss()
        }
    }

    @MainActor
    private func startDownload() async {
        guard let selectedVersion = selectedModPackVersion,
              let projectDetail = viewModel.projectDetail
        else { return }

        viewModel.beginDownloadAndInstall(
            selectedVersion: selectedVersion,
            projectDetail: projectDetail,
            gameName: gameNameValidator.gameName,
            selectedGameVersion: selectedGameVersion,
            gameSetupService: gameSetupService,
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}
