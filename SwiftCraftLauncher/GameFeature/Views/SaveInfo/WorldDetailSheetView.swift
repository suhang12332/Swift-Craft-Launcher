//
//  WorldDetailSheetView.swift
//  SwiftCraftLauncher
//
//  Created by su on 2025/1/29.
//

import SwiftUI

/// 世界详细信息视图（读取 level.dat）
struct WorldDetailSheetView: View {
    // MARK: - Properties
    @StateObject private var viewModel: WorldDetailSheetViewModel
    @Environment(\.dismiss)
    private var dismiss

    init(world: WorldInfo, gameName: String) {
        _viewModel = StateObject(wrappedValue: WorldDetailSheetViewModel(world: world, gameName: gameName))
    }

    // MARK: - Body
    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView }
        )
        .frame(minWidth: 500, minHeight: 400)
        .task {
            await viewModel.loadMetadata()
        }
        .alert(
            "common.error".localized(),
            isPresented: Binding(
                get: { viewModel.showError },
                set: { viewModel.showError = $0 }
            )
        ) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text(viewModel.world.name)
                .font(.headline)
            Spacer()
            if let seed = viewModel.seed,
               let url = URLConfig.API.ChunkBase.seedMap(seed: seed) {
                Link(destination: url) {
                    Image(systemName: "safari")
                }
                .controlSize(.large)
                .foregroundStyle(.secondary)
                .bold()
            }
        }
    }

    // MARK: - Body View
    private var bodyView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let metadata = viewModel.metadata {
                metadataContentView(metadata: metadata)
            } else {
                errorView
            }
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("saveinfo.world.detail.load.failed".localized())
                .font(.headline)
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func metadataContentView(metadata: WorldDetailMetadata) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 24) {
                    WorldDetailBasicInfoSectionView(metadata: metadata)
                    WorldDetailGameSettingsSectionView(metadata: metadata)
                }
                if let seed = metadata.seed {
                    SeedCopyRow(seed: seed)
                }
                WorldDetailOtherInfoSectionView(metadata: metadata)
                WorldDetailPathRowView(worldPath: metadata.path)
                if let filteredRaw = viewModel.filteredRawData {
                    WorldDetailRawDataToggleView(
                        filteredRawData: filteredRaw,
                        showRawData: $viewModel.showRawData
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Label {
                Text(viewModel.gameName)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "gamecontroller")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()

            Button("common.close".localized()) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}
