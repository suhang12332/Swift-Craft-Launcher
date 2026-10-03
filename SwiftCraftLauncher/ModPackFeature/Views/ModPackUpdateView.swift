//
//  ModPackUpdateView.swift
//  ModPackFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import SwiftUI

struct ModPackUpdateView: View {
    @Environment(GameRepository.self)
    private var gameRepository
    @Environment(\.dismiss)
    private var dismiss
    @State private var viewModel: ModPackUpdateViewModel

    init(game: GameVersionInfo) {
        _viewModel = State(initialValue: ModPackUpdateViewModel(game: game))
    }

    var body: some View {
        CommonSheetView(
            header: {
                Text("modpack.update.title".localized()).font(.headline)
            },
            body: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(viewModel.game.gameName).font(.headline)
                    Text("modpack.update.rules".localized())
                        .foregroundStyle(.secondary)
                    if let installed = viewModel.installedPack {
                        Text(installed.versionName)
                    } else {
                        Text("modpack.update.link.help".localized())
                        TextField("modpack.update.project".localized(), text: $viewModel.projectId)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: viewModel.projectId) { _, _ in
                                viewModel.versions = []
                                viewModel.selectedVersionId = ""
                            }
                    }
                    if !viewModel.versions.isEmpty {
                        Picker("modpack.version".localized(), selection: $viewModel.selectedVersionId) {
                            ForEach(viewModel.versions) { version in
                                Text("\(version.name) (\(version.versionType))").tag(version.id)
                            }
                        }
                    } else if !viewModel.isBusy, viewModel.installedPack != nil {
                        Text("modpack.update.no_versions".localized()).foregroundStyle(.secondary)
                    }
                    if viewModel.isBusy {
                        ProgressView()
                    }
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red).textSelection(.enabled)
                    }
                    if let backup = viewModel.backup {
                        Button("modpack.update.backup".localized()) {
                            NSWorkspace.shared.activateFileViewerSelecting([backup])
                        }
                    }
                }
                .disabled(viewModel.isBusy)
            },
            footer: {
                HStack {
                    Button("common.close".localized()) { dismiss() }
                        .disabled(viewModel.isBusy)
                    Spacer()
                    Button("modpack.update.check".localized()) {
                        Task { await viewModel.loadVersions() }
                    }
                    .disabled(viewModel.isBusy || viewModel.projectId.isEmpty)
                    Button((viewModel.installedPack == nil ? "modpack.update.link" : "modpack.update.title").localized()) {
                        Task { await viewModel.confirm(repository: gameRepository) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBusy || viewModel.selectedVersionId.isEmpty)
                }
            },
        )
        .interactiveDismissDisabled(viewModel.isBusy)
        .task {
            if viewModel.installedPack != nil {
                await viewModel.loadVersions()
            }
        }
    }
}
