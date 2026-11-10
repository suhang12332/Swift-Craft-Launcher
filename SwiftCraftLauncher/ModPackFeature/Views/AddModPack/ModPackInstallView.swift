//
//  ModPackInstallView.swift
//  ModPackFeature
//
//  © 2025 Swift Craft Launcher Team. All rights reserved.
//

import SwiftUI

/// Shared installation form for local imports, direct URL downloads, and online projects.
struct ModPackInstallView: View {
    @State private var viewModel: ModPackInstallViewModel
    @Environment(GameRepository.self)
    private var gameRepository

    private let triggerConfirm: Binding<Bool>
    private let triggerCancel: Binding<Bool>

    init(
        source: ModPackInstallSource,
        configuration: GameFormConfiguration,
    ) {
        triggerConfirm = configuration.triggerConfirm
        triggerCancel = configuration.triggerCancel

        _viewModel = State(
            wrappedValue: ModPackInstallViewModel(
                source: source,
                configuration: configuration,
            ),
        )
    }

    var body: some View {
        VStack {
            content
        }
        .onAppear {
            viewModel.setup(gameRepository: gameRepository)
        }
        .gameFormStateListeners(
            viewModel: viewModel,
            triggerConfirm: triggerConfirm,
            triggerCancel: triggerCancel,
        )
        .onChange(of: viewModel.modPackInstallState.isInstalling) { _, _ in
            viewModel.updateParentState()
        }
        .onDisappear {
            if viewModel.isCancellable {
                viewModel.handleCancel()
            } else {
                viewModel.cleanupPreviewState()
            }
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.isDownloadingArchive {
            DownloadingProgressView(
                progress: viewModel.modPackDownloadProgress,
                totalSize: viewModel.modPackTotalSize,
                title: "modpack.processing.title".localized(),
                subtitle: viewModel.processingSubtitleKey.localized(),
            )
        } else if viewModel.isPreparingArchive {
            processingView
        } else {
            switch viewModel.source {
            case .local:
                localContent
            case .remoteURL:
                remoteURLContent
            case .project:
                projectContent
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            ProgressView().controlSize(.small)

            Text("modpack.processing.title".localized())
                .font(.headline)
                .foregroundColor(.primary)

            Text(viewModel.processingSubtitleKey.localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder private var localContent: some View {
        if viewModel.prepared != nil {
            preparedContent
        } else if viewModel.didFailPreparation {
            errorView(message: "error.resource.modpack_parse_failed".localized())
        } else {
            processingView
        }
    }

    @ViewBuilder private var remoteURLContent: some View {
        if viewModel.prepared != nil {
            preparedContent
        } else {
            VStack(alignment: .leading, spacing: 16) {
                urlInfoSection
                urlInputSection

                if viewModel.didFailPreparation {
                    errorView(message: "error.resource.modpack_parse_failed".localized())
                }
            }
        }
    }

    private var urlInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("modpack.url_download.title".localized())
                .font(.headline)
                .padding(.bottom, 4)

            Text("modpack.url_download.info".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            Text("modpack.url_download.example.modrinth".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("modpack.url_download.example.curseforge".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("modpack.url_download.example.other".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var urlInputSection: some View {
        VStack(alignment: .leading) {
            Text("modpack.url_download.label".localized())
                .font(.headline)
            TextField(
                "modpack.url_download.placeholder".localized(),
                text: Binding(
                    get: { viewModel.urlString },
                    set: { viewModel.urlString = $0 },
                ),
            )
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
        }
    }

    @ViewBuilder private var preparedContent: some View {
        if viewModel.isPreparedGameVersionSupported {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.modPackName)
                        .font(.title2)
                        .bold()
                    selectedModPackInfoRow
                }

                sharedSections
            }
        } else {
            errorView(
                message: String(
                    format: "error.resource.modpack_game_version_unsupported".localized(),
                    AppConstants.MinecraftVersions.featureBaseline,
                ),
            )
        }
    }

    private var selectedModPackInfoRow: some View {
        HStack(spacing: 8) {
            Label(viewModel.modPackVersion, systemImage: "text.document.fill")
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

    @ViewBuilder private var projectContent: some View {
        if let projectDetail = viewModel.projectDetail {
            VStack(alignment: .leading, spacing: 12) {
                ModrinthProjectTitleView(projectDetail: projectDetail)
                    .padding(.bottom, 18)

                versionSelection
                    .disabled(viewModel.isDownloading)

                if !viewModel.selectedGameVersion.isEmpty, !viewModel.isLoadingModPackVersions {
                    sharedSections
                }
            }
        } else if viewModel.isLoadingProjectDetails {
            ProgressView().controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 130)
        }
    }

    private var versionSelection: some View {
        @Bindable var viewModel = viewModel
        return VersionSelectionView(
            selectedGameVersion: $viewModel.selectedGameVersion,
            selectedModPackVersion: $viewModel.selectedModPackVersion,
            availableGameVersions: viewModel.availableGameVersions,
            filteredModPackVersions: viewModel.filteredModPackVersions,
            isLoadingModPackVersions: viewModel.isLoadingModPackVersions,
            onGameVersionChange: viewModel.handleGameVersionChange,
            onModPackVersionAppear: viewModel.selectFirstModPackVersion,
        )
    }

    private var sharedSections: some View {
        ModPackInstallSharedSections(
            gameName: Binding(
                get: { viewModel.gameNameValidator.gameName },
                set: { viewModel.gameNameValidator.gameName = $0 },
            ),
            isGameNameDuplicate: Binding(
                get: { viewModel.gameNameValidator.isGameNameDuplicate },
                set: { viewModel.gameNameValidator.isGameNameDuplicate = $0 },
            ),
            isGameNameInputDisabled: viewModel.isDownloading,
            showGameNameInput: true,
            gameInstaller: viewModel.gameInstaller,
            modPackInstallState: viewModel.modPackInstallState,
            lastParsedIndexInfo: viewModel.lastParsedIndexInfo,
            shouldShowProgress: viewModel.shouldShowProgress,
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up.trianglebadge.exclamationmark")
                .symbolRenderingMode(.multicolor)
                .symbolVariant(.none)
                .foregroundStyle(.secondary)
                .font(.largeTitle)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
