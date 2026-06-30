//
//  ModPackImportView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A form view for importing a modpack from a local file.
struct ModPackImportView: View {
    @StateObject private var viewModel: ModPackImportViewModel
    @EnvironmentObject private var gameRepository: GameRepository

    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>
    @EnvironmentObject private var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    init(
        configuration: GameFormConfiguration,
        preselectedFile: URL? = nil,
        shouldStartProcessing: Bool = false,
        onProcessingStateChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.triggerConfirm = configuration.triggerConfirm
        self.triggerCancel = configuration.triggerCancel

        self._viewModel = StateObject(wrappedValue: ModPackImportViewModel(
            configuration: configuration,
            preselectedFile: preselectedFile,
            shouldStartProcessing: shouldStartProcessing,
            onProcessingStateChanged: onProcessingStateChanged
        ))
    }

    var body: some View {
        formContentView
        .onAppear {
            viewModel.setup(gameRepository: gameRepository)
        }
        .gameFormStateListeners(viewModel: viewModel, triggerConfirm: triggerConfirm, triggerCancel: triggerCancel)
        .onChange(of: viewModel.selectedModPackFile) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.updateParentState()
            }
        }
        .onChange(of: viewModel.modPackIndexInfo?.modPackName) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.updateParentState()
            }
        }
        .onChange(of: viewModel.modPackViewModelForProgress.modPackInstallState.isInstalling) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.updateParentState()
            }
        }
        .onChange(of: viewModel.isProcessingModPack) { oldValue, newValue in
            if oldValue != newValue {
                viewModel.updateParentState()
            }
        }
        .onDisappear {
            clearAllData()
        }
    }

    private func clearAllData() {
        if viewModel.isDownloading {
            viewModel.cancelDownloadIfNeeded()
        }
    }

    private var formContentView: some View {
        VStack {
            modPackImportContentView.padding(.bottom, 10)
            if viewModel.hasSelectedModPack
                && viewModel.isGameVersionSupported
                && viewModel.modPackIndexInfo != nil {
                modPackGameNameInputSection
            }

            if viewModel.shouldShowProgress {
                EmptyView()
                    .padding(.top, 10)
            }
        }
    }

    private var gameVersionUnsupportedHint: some View {
        modPackErrorView(
            message: String(format: "error.resource.modpack_game_version_unsupported".localized(), AppConstants.MinecraftVersions.featureBaseline)
        )
    }

    private var modPackImportContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isProcessingModPack && !viewModel.shouldShowProgress {
                modPackProcessingView
            } else if !viewModel.isGameVersionSupported {
                gameVersionUnsupportedHint
            } else {
                selectedModPackView
            }
        }
    }

    private var modPackProcessingView: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.small)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text("modpack.processing.subtitle.local".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var modPackParseErrorView: some View {
        modPackErrorView(message: "error.resource.modpack_parse_failed".localized())
    }

    private func modPackErrorView(
        message: String
    ) -> some View {
        return VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundStyle(.secondary)
                .font(.system(size: 32))
            Text(viewModel.selectedModPackFile?.lastPathComponent ?? "")
                .font(.headline)
                .bold()

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var selectedModPackView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.modPackIndexInfo != nil {
                HStack {
                    VStack(alignment: .leading) {
                        Text(viewModel.modPackName)
                            .font(.title2)
                            .bold()
                        selectedModPackInfoRow
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
            } else {
                modPackParseErrorView
            }
        }
    }

    private var selectedModPackInfoRow: some View {
        HStack(spacing: 8) {
            Label(
                viewModel.modPackVersion,
                systemImage: "text.document.fill"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(viewModel.gameVersion, systemImage: "gamecontroller.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .frame(height: 14)

            Label(viewModel.loaderInfo, systemImage: "puzzlepiece.extension.fill")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var modPackGameNameInputSection: some View {
        ModPackInstallSharedSections(
            gameName: Binding(
                get: { viewModel.gameNameValidator.gameName },
                set: { viewModel.gameNameValidator.gameName = $0 }
            ),
            isGameNameDuplicate: Binding(
                get: { viewModel.gameNameValidator.isGameNameDuplicate },
                set: { viewModel.gameNameValidator.isGameNameDuplicate = $0 }
            ),
            isGameNameInputDisabled: viewModel.isProcessingModPack || viewModel.isDownloading,
            showGameNameInput: true,
            gameSetupService: viewModel.gameSetupService,
            modPackInstallState: viewModel.modPackViewModelForProgress.modPackInstallState,
            lastParsedIndexInfo: viewModel.modPackIndexInfo,
            shouldShowProgress: viewModel.shouldShowProgress
        )
    }
}
