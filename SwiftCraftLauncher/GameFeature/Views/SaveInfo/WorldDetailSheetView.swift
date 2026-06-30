//
//  WorldDetailSheetView.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

// Displays world details read from level.dat including game settings, seed, and NBT data.
import SwiftUI

struct WorldDetailSheetView: View {
    @StateObject private var viewModel: WorldDetailSheetViewModel
    @Environment(\.dismiss)
    private var dismiss

    init(viewModel: WorldDetailSheetViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyView },
            footer: { footerView },
        )
        .frame(minWidth: 500, minHeight: 400)
        .alert(
            "common.error".localized(),
            isPresented: Binding(
                get: { viewModel.showError },
                set: { viewModel.showError = $0 },
            ),
        ) {
            Button("common.ok".localized(), role: .cancel) { }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyView: some View {
        Group {
            if let metadata = viewModel.metadata {
                metadataContentView(metadata: metadata)
            }
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        showRawData: $viewModel.showRawData,
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

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
