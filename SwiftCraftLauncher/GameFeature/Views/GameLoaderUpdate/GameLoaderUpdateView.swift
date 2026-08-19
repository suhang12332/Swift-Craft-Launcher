//
//  GameLoaderUpdateView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A sheet for changing the loader version on an existing game instance, reusing the
// installation pipeline and download progress UI. When the game is vanilla, the user
// can choose a mod loader type to add. The game version is never changed.
import SwiftUI

struct GameLoaderUpdateView: View {
    let gameInfo: GameVersionInfo

    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel: GameLoaderUpdateViewModel

    init(gameInfo: GameVersionInfo) {
        self.gameInfo = gameInfo
        _viewModel = State(initialValue: GameLoaderUpdateViewModel(existingGame: gameInfo))
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
        Text("game.loader.update.title".localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentInfoSection
                .padding(.bottom, 10)
            if !viewModel.isUpdating {
                if viewModel.canChangeLoaderType {
                    loaderTypeSelectionSection
                }
                versionSelectionSection
            }

            if viewModel.isUpdating {
                DownloadProgressSection(
                    gameSetupService: viewModel.gameSetupService,
                    selectedModLoader: viewModel.selectedModLoader,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
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
