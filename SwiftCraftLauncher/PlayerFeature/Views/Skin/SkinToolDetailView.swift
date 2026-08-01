//
//  SkinToolDetailView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Foundation
import SkinRenderKit
import SwiftUI
import UniformTypeIdentifiers

/// A sheet for managing the current player's skin and cape.
struct SkinToolDetailView: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(PlayerListViewModel.self)
    private var playerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    @State private var viewModel: SkinToolDetailViewModel

    init(
        preloadedSkinInfo: PlayerSkinService.PublicSkinInfo? = nil,
        preloadedProfile: MinecraftProfileResponse? = nil,
    ) {
        _viewModel = State(
            wrappedValue: SkinToolDetailViewModel(
                preloadedSkinInfo: preloadedSkinInfo,
                preloadedProfile: preloadedProfile,
            ),
        )
    }

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyContentView },
            footer: { footerView },
        )
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false,
        ) { result in
            viewModel.handleFileSelection(result)
        }
        .onAppear {
            let ok = viewModel.onAppear(resolvedPlayer: resolvedPlayer)
            if !ok {
                dismiss()
            }
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    private var headerView: some View {
        Text("skin.manager".localized()).font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyContentView: some View {
        VStack(spacing: 24) {
            PlayerInfoSectionView(
                player: resolvedPlayer,
                currentModel: $viewModel.currentModel,
            )
            .onChange(of: viewModel.currentModel) { _, _ in
                viewModel.updateHasChanges()
            }

            SkinUploadSectionView(
                currentModel: $viewModel.currentModel,
                showingFileImporter: $viewModel.showingFileImporter,
                selectedSkinImage: $viewModel.selectedSkinImage,
                selectedSkinPath: $viewModel.selectedSkinPath,
                currentSkinRenderImage: $viewModel.currentSkinRenderImage,
                selectedCapeLocalPath: $viewModel.selectedCapeLocalPath,
                selectedCapeImage: $viewModel.selectedCapeImage,
                selectedCapeImageURL: $viewModel.selectedCapeImageURL,
                isCapeLoading: $viewModel.isCapeLoading,
                capeLoadCompleted: $viewModel.capeLoadCompleted,
                showingSkinPreview: $viewModel.showingSkinPreview,
                showSkinLibrary: container.ui.playerSettingsManager.enableHistorySkinLibrary,
                onSkinDropped: { image in
                    viewModel.handleSkinDroppedImage(image)
                },
                onDrop: { providers in
                    viewModel.handleDrop(providers)
                },
                onSelectSkinLibraryItem: { item in
                    viewModel.selectSkinLibraryItem(item)
                },
            )

            CapeSelectionView(
                playerProfile: viewModel.playerProfile,
                selectedCapeId: $viewModel.selectedCapeId,
                selectedCapeImageURL: $viewModel.selectedCapeImageURL,
                selectedCapeImage: $viewModel.selectedCapeImage,
            ) { id, imageURL in
                viewModel.handleCapeSelection(id: id, imageURL: imageURL, resolvedPlayer: resolvedPlayer)
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("common.cancel".localized()) { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()

            HStack(spacing: 12) {
                if resolvedPlayer?.isOnlineAccount == true {
                    Button("skin.reset".localized()) {
                        viewModel.resetSkin(resolvedPlayer: resolvedPlayer)
                    }
                    .disabled(viewModel.operationInProgress)
                }
                Button("skin.apply".localized()) {
                    viewModel.applyChanges(resolvedPlayer: resolvedPlayer) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.operationInProgress || !viewModel.hasChanges)
            }
        }
    }

    var resolvedPlayer: Player? { playerListViewModel.currentPlayer }
}
