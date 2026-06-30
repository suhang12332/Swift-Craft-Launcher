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
    @EnvironmentObject private var gameRepository: GameRepository
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var viewModel = ModPackDownloadSheetViewModel()
    @StateObject private var coordinator = ModPackDownloadSheetCoordinatorViewModel()
    @State private var selectedGameVersion: String = ""
    @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
    @StateObject private var gameSetupService = GameSetupUtil()
    @StateObject private var gameNameValidator: GameNameValidator

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
        _gameNameValidator = StateObject(wrappedValue: GameNameValidator(gameSetupService: GameSetupUtil()))
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

    private var processView: some View {
        VStack(spacing: 24) {
            ProgressView(
                value: Double(max(viewModel.modPackDownloadProgress, 0)),
                total: Double(max(viewModel.modPackTotalSize, 100)),
            )
            .progressViewStyle(.circular)
            .controlSize(.extraLarge)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle.remote".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }.padding()
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isProcessing {
                processView
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
                    Text("modpack.download.button".localized())
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
