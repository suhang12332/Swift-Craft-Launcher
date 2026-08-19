//
//  GameLoaderUpdateView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// A sheet for changing the loader version on an existing game instance, reusing the
// installation pipeline and download progress UI. The loader type is fixed to the
// game's current loader — cross-loader switching is not allowed.
import SwiftUI

private enum Constants {
    static let formSpacing: CGFloat = 16
}

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
        VStack(spacing: Constants.formSpacing) {
            gameInfoSection
            currentLoaderSection

            if !viewModel.isUpdating {
                loaderSelectionSection
            }

            if viewModel.shouldShowProgress {
                DownloadProgressSection(
                    gameSetupService: viewModel.gameSetupService,
                    selectedModLoader: viewModel.selectedModLoader,
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var gameInfoSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: Constants.formSpacing) {
                infoRow(
                    title: "game.loader.update.game".localized(),
                    value: gameInfo.gameName,
                )
                infoRow(
                    title: "game.form.version".localized(),
                    value: gameInfo.gameVersion,
                )
            }
        }
    }

    private var currentLoaderSection: some View {
        FormSection {
            infoRow(
                title: "game.loader.update.current".localized(),
                value: viewModel.currentLoaderDescription,
            )
        }
    }

    private var loaderSelectionSection: some View {
        FormSection {
            VStack(alignment: .leading, spacing: Constants.formSpacing) {
                if viewModel.selectedModLoader != GameLoader.vanilla.displayName {
                    loaderVersionPicker
                }
            }
        }
    }

    private var loaderVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
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

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: 220, alignment: .trailing)
                .multilineTextAlignment(.trailing)
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
                    if viewModel.isUpdating || viewModel.isLoadingLoaderVersions {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("game.loader.update.confirm".localized())
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.isFormValid || viewModel.isUpdating || viewModel.isLoadingLoaderVersions)
        }
    }
}
