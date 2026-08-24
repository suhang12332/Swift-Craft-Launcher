//
//  GameLoaderUpdateView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A sheet for changing the loader version on an existing game instance, reusing the
// installation pipeline and download progress UI. When the game is vanilla, the user
// can choose a mod loader type to add. The game version is never changed.
//
// In ``GameLoaderUpdateMode.repair`` mode it instead repairs the game by re-fetching
// missing or corrupted files, preserving the current loader type and version.
import SwiftUI

struct GameLoaderUpdateView: View {
    let gameInfo: GameVersionInfo
    let mode: GameLoaderUpdateMode

    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel: GameLoaderUpdateViewModel

    init(gameInfo: GameVersionInfo, mode: GameLoaderUpdateMode = .adjust) {
        self.gameInfo = gameInfo
        self.mode = mode
        _viewModel = State(initialValue: GameLoaderUpdateViewModel(existingGame: gameInfo, mode: mode))
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView },
        )
        .onAppear {
            viewModel.setup(gameRepository: gameRepository)
            viewModel.onSuccess = { dismiss() }
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var headerView: some View {
        Text((mode == .repair ? "game.repair.title" : "game.loader.update.title").localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if mode == .repair {
                repairInfoSection
            } else {
                currentInfoSection
                    .padding(.bottom, 10)
            }
            if !viewModel.isUpdating {
                if mode == .adjust {
                    if viewModel.canChangeLoaderType {
                        loaderTypeSelectionSection
                    }
                    versionSelectionSection
                }
            } else {
                DownloadProgressSection(
                    gameSetupService: viewModel.gameSetupService,
                    selectedModLoader: viewModel.selectedModLoader,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var repairInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("game.repair.rules.header".localized())
                .font(.headline)
                .padding(.bottom, 4)

            Text("game.repair.rules.rule.1".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("game.repair.rules.rule.2".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("game.repair.rules.rule.3".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }

    private var currentInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("game.loader.update.rules.header".localized())
                .font(.headline)
                .padding(.bottom, 4)

            Text("game.loader.update.rules.rule.1".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("game.loader.update.rules.rule.2".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("game.loader.update.rules.rule.3".localized())
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var loaderTypeSelectionSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("game.form.modloader".localized())
                    .font(.headline)
                Spacer()
                if viewModel.isLoadingLoaderTypes {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.85)
                }
            }
            CommonMenuPicker(selection: $viewModel.selectedModLoader) {
                ForEach(viewModel.availableLoaderTypes) { loader in
                    Text(loader.labelName).tag(loader.displayName)
                }
            }
            .disabled(viewModel.isLoadingLoaderTypes || viewModel.availableLoaderTypes.isEmpty)
            .onChange(of: viewModel.selectedModLoader) { _, _ in
                viewModel.onLoaderTypeChanged()
            }
        }
    }

    private var versionSelectionSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("game.form.loader.version".localized())
                    .font(.headline)
                Spacer()
                if viewModel.isLoadingLoaderVersions {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.85)
                }
            }
            CommonMenuPicker(selection: $viewModel.selectedLoaderVersion) {
                ForEach(viewModel.availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .disabled(viewModel.isLoadingLoaderVersions || viewModel.availableLoaderVersions.isEmpty)
        }
    }

    private var footerView: some View {
        HStack {
            Button {
                if viewModel.isUpdating {
                    viewModel.cancel()
                } else {
                    dismiss()
                }
            } label: {
                Text(viewModel.isUpdating ? "common.stop".localized() : "common.cancel".localized())
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button {
                viewModel.confirm()
            } label: {
                HStack {
                    if viewModel.isUpdating || viewModel.isLoadingLoaderVersions || viewModel.isLoadingLoaderTypes {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("common.confirm".localized())
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.isFormValid || viewModel.isLoadingLoaderTypes)
        }
    }
}
