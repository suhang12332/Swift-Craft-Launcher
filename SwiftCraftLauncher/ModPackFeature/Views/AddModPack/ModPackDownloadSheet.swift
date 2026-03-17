//
//  ModPackDownloadSheet.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/8/2.
//

import SwiftUI

struct ModPackDownloadSheet: View {
    let projectId: String
    let gameInfo: GameVersionInfo?
    let query: String
    let preloadedDetail: ModrinthProjectDetail?
    @EnvironmentObject private var gameRepository: GameRepository
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var viewModel = ModPackDownloadSheetViewModel()
    @State private var selectedGameVersion: String = ""
    @State private var selectedModPackVersion: ModrinthProjectDetailVersion?
    @StateObject private var gameSetupService = GameSetupUtil()
    @StateObject private var gameNameValidator: GameNameValidator

    // MARK: - Initializer
    init(
        projectId: String,
        gameInfo: GameVersionInfo?,
        query: String,
        preloadedDetail: ModrinthProjectDetail? = nil
    ) {
        self.projectId = projectId
        self.gameInfo = gameInfo
        self.query = query
        self.preloadedDetail = preloadedDetail
        self._gameNameValidator = StateObject(wrappedValue: GameNameValidator(gameSetupService: GameSetupUtil()))
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .onAppear {
            viewModel.setGameRepository(gameRepository)
            if let preloadedDetail {
                viewModel.applyPreloadedDetail(preloadedDetail)
            } else {
                Task {
                    await viewModel.loadProjectDetails(projectId: projectId)
                }
            }
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 清理选中的版本
        selectedGameVersion = ""
        selectedModPackVersion = nil
        // 清理 ViewModel 所有数据和临时文件 + 停止下载/安装状态
        viewModel.cancelDownloadAndResetStates(gameSetupService: gameSetupService)
        viewModel.cleanupAllData()
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack {
            Text("modpack.download.title".localized())
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var processView: some View {
        VStack(spacing: 24) {
            ProgressView(
                value: Double(max(viewModel.modPackDownloadProgress, 0)),
                total: Double(max(viewModel.modPackTotalSize, 100))
            )
            .progressViewStyle(.circular)
            .controlSize(.extraLarge)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle".localized())
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
                    onModPackVersionAppear: selectFirstModPackVersion
                )

                if !selectedGameVersion.isEmpty && selectedModPackVersion != nil {
                    gameNameInputSection
                }

                if shouldShowProgress {
                    DownloadProgressView(
                        gameSetupService: gameSetupService,
                        modPackInstallState: viewModel.modPackInstallState,
                        lastParsedIndexInfo: viewModel.lastParsedIndexInfo
                    )
                    .padding(.top, 18)
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

    // MARK: - Computed Properties

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

    // MARK: - UI Components

    private var gameNameInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !selectedGameVersion.isEmpty && selectedModPackVersion != nil {
                GameNameInputView(
                    gameName: $gameNameValidator.gameName,
                    isGameNameDuplicate: $gameNameValidator.isGameNameDuplicate,
                    isDisabled: viewModel.isProcessing,
                    gameSetupService: gameSetupService
                )
            }
        }
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

    // MARK: - Helper Methods

    private func handleGameVersionChange(_ newValue: String) {
        if !newValue.isEmpty {
            Task {
                await viewModel.loadModPackVersions(for: newValue)
            }
            // 设置默认游戏名称
            setDefaultGameName()
        } else {
            viewModel.filteredModPackVersions = []
        }
    }

    private func selectFirstModPackVersion() {
        if !viewModel.filteredModPackVersions.isEmpty
            && selectedModPackVersion == nil {
            selectedModPackVersion = viewModel.filteredModPackVersions[0]
            // 设置默认游戏名称
            setDefaultGameName()
        }
    }

    private func setDefaultGameName() {
        let defaultName = GameNameGenerator.generateModPackName(
            projectTitle: viewModel.projectDetail?.title,
            gameVersion: selectedGameVersion,
            includeTimestamp: true
        )
        gameNameValidator.setDefaultName(defaultName)
    }

    private func handleCancel() {
        if isDownloading {
            Task {
                viewModel.cancelDownloadAndResetStates(gameSetupService: gameSetupService)
                await viewModel.cleanupGameDirectoriesForCancel(gameName: gameNameValidator.gameName)
            }
            // 停止后直接关闭sheet
            dismiss()
        } else {
            dismiss()
        }
    }

    // MARK: - Download Action

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
            gameSetupService: gameSetupService
        ) { success in
            if success {
                dismiss()
            }
        }
    }
}
