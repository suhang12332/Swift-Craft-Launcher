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
    @State private var gameInstaller = GameInstaller()
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
        _gameNameValidator = State(wrappedValue: GameNameValidator())
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
            gameInstaller: gameInstaller,
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
                    onGameVersionChange: handleGameVersionChange,
                    onModPackVersionAppear: selectFirstModPackVersion,
                )
                .disabled(isDownloading)

                if !selectedGameVersion.isEmpty, !viewModel.isLoadingModPackVersions {
                    ModPackInstallSharedSections(
                        gameName: $gameNameValidator.gameName,
                        isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                        isGameNameInputDisabled: isDownloading,
                        showGameNameInput: true,
                        gameInstaller: gameInstaller,
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
        gameInstaller.progress.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var canDownload: Bool {
        !selectedGameVersion.isEmpty && selectedModPackVersion != nil && gameNameValidator.isFormValid
    }

    private var isDownloading: Bool {
        viewModel.isProcessing || gameInstaller.progress.isDownloading
            || viewModel.modPackInstallState.isInstalling
    }

    private var isButtonLoading: Bool {
        isDownloading || viewModel.isLoadingProjectDetails || viewModel.isLoadingModPackVersions
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
                if isButtonLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("global_resource.download".localized())
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canDownload || isButtonLoading)
    }

    private func handleGameVersionChange(_ newValue: String) {
        guard !newValue.isEmpty else { return }

        viewModel.loadModPackVersions(for: newValue)
        setDefaultGameName()
    }

    private func selectFirstModPackVersion() {
        if !viewModel.filteredModPackVersions.isEmpty,
           selectedModPackVersion == nil {
            selectedModPackVersion = viewModel.filteredModPackVersions[0]
        }
    }

    private func setDefaultGameName() {
        gameNameValidator.gameName = GameNameGenerator.generateModPackName(
            projectTitle: viewModel.projectDetail?.title,
            gameVersion: selectedGameVersion,
            includeTimestamp: true,
        )
    }

    private func handleCancel() {
        if isDownloading {
            Task {
                await viewModel.cancelInstallation(
                    gameName: gameNameValidator.gameName,
                    gameInstaller: gameInstaller,
                )
            }
        }
        dismiss()
    }

    @MainActor
    private func startDownload() async {
        guard let selectedVersion = selectedModPackVersion,
              let projectDetail = viewModel.projectDetail
        else { return }

        viewModel.beginDownloadAndInstall(
            selectedVersion: selectedVersion,
            projectDetail: projectDetail,
            gameName: gameNameValidator.gameName.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedGameVersion: selectedGameVersion,
            gameInstaller: gameInstaller,
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}
