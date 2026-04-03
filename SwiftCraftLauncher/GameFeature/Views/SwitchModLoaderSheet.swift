//
//  SwitchModLoaderSheet.swift
//  SwiftCraftLauncher
//
//  Created by Hongbro886 on 2026/4/2.
//

import SwiftUI

struct SwitchModLoaderSheet: View {
    @StateObject private var viewModel: SwitchModLoaderSheetViewModel
    @Environment(\.dismiss)
    var dismiss
    @EnvironmentObject var gameRepository: GameRepository

    init(gameInfo: GameVersionInfo) {
        _viewModel = StateObject(wrappedValue: SwitchModLoaderSheetViewModel(gameInfo: gameInfo))
    }

    private var headerView: some View {
        Text("switch.modloader.title".localized())
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var bodyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 当前游戏信息
            VStack(alignment: .leading, spacing: 8) {
                Text("switch.modloader.current_game".localized())
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Text(viewModel.gameInfo.gameName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text("-")
                        .foregroundColor(.secondary)
                    Text(viewModel.gameInfo.gameVersion)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // ModLoader选择
            modLoaderPicker

            // 加载器版本选择
            if viewModel.selectedModLoader != GameLoader.vanilla.displayName {
                loaderVersionPicker
            }

            // 版本加载错误提示
            if let versionError = viewModel.versionLoadError {
                Text(versionError)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
            }

            // 安装进度
            if viewModel.isInstalling {
                installProgressView
            }

            // 安装错误信息
            if let error = viewModel.installError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            viewModel.setDependencies(gameRepository: gameRepository)
            viewModel.initializeDefaultLoader()
        }
        .onChange(of: viewModel.selectedModLoader) { _, newLoader in
            viewModel.handleModLoaderChange(newLoader)
        }
    }

    private var modLoaderPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.modloader".localized())
                .font(.subheadline)
                .foregroundColor(.primary)
            CommonMenuPicker(
                selection: $viewModel.selectedModLoader,
                hidesLabel: true
            ) {
                Text("")
            } content: {
                ForEach(viewModel.availableModLoaders, id: \.self) { loader in
                    switch loader {
                    case GameLoader.fabric.displayName:
                        Text("modloader.fabric.text".localized()).tag(loader)
                    case GameLoader.forge.displayName:
                        Text("modloader.forge.text".localized()).tag(loader)
                    case GameLoader.neoforge.displayName:
                        Text("modloader.neoforge.text".localized()).tag(loader)
                    case GameLoader.quilt.rawValue:
                        Text("modloader.quilt.text".localized()).tag(loader)
                    default:
                        Text(loader.capitalized).tag(loader)
                    }
                }
            }
            .disabled(viewModel.isInstalling || viewModel.isLoadingVersions)
        }
    }

    private var loaderVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("game.form.loader.version".localized())
                .font(.subheadline)
                .foregroundColor(.primary)

            CommonMenuPicker(
                selection: $viewModel.selectedLoaderVersion,
                hidesLabel: true
            ) {
                Text("")
            } content: {
                ForEach(viewModel.availableLoaderVersions, id: \.self) { version in
                    Text(version).tag(version)
                }
            }
            .disabled(viewModel.isInstalling || viewModel.isLoadingVersions || viewModel.availableLoaderVersions.isEmpty)
        }
    }

    private var installProgressView: some View {
        FormSection {
            DownloadProgressRow(
                title: "switch.modloader.installing".localized(),
                progress: Double(viewModel.installProgress.completed) / Double(max(viewModel.installProgress.total, 1)),
                currentFile: viewModel.installProgress.message,
                completed: viewModel.installProgress.completed,
                total: viewModel.installProgress.total,
                version: viewModel.selectedLoaderVersion
            )
        }
        .padding(.top, 8)
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .disabled(viewModel.isInstalling)

            Spacer()

            Button {
                Task {
                    let success = await viewModel.installModLoader()
                    if success {
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isInstalling {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                } else {
                    Text("resource.add".localized())
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canInstall)
        }
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(width: 400)
    }
}

// MARK: - Preview
#Preview {
    SwitchModLoaderSheet(gameInfo: GameVersionInfo(
        gameName: "Test Game",
        gameIcon: "",
        gameVersion: "1.20.1",
        assetIndex: "",
        modLoader: "vanilla"
    ))
    .environmentObject(GameRepository())
}
