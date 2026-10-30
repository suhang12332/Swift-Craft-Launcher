//
//  SkinUploadSectionView.swift
//  PlayerFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import Foundation
import SkinRenderKit
import SwiftUI
import UniformTypeIdentifiers

/// Provides the skin upload area, render preview, and library access.
struct SkinUploadSectionView: View {
    @Environment(DIContainer.self)
    private var container
    @Binding var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel
    @Binding var showingFileImporter: Bool
    @Binding var selectedSkinImage: NSImage?
    @Binding var selectedSkinPath: String?
    @Binding var currentSkinRenderImage: NSImage?
    @Binding var selectedCapeImage: NSImage?
    let showSkinLibrary: Bool
    @State private var showingSkinLibraryPopover = false
    @State private var skinLibraryItems: [SkinLibraryItem] = []
    @State private var skinLibraryCursor: SkinLibraryItem?
    @State private var skinLibraryHasMore = false
    @State private var pendingDeletion: SkinLibraryItem?

    let onSkinDropped: (NSImage) -> Void
    let onDrop: ([NSItemProvider]) -> Bool
    let onSelectSkinLibraryItem: (SkinLibraryItem) -> Void
    private let skinLibraryStore: SkinLibraryStore

    init(
        currentModel: Binding<PlayerSkinService.PublicSkinInfo.SkinModel>,
        showingFileImporter: Binding<Bool>,
        selectedSkinImage: Binding<NSImage?>,
        selectedSkinPath: Binding<String?>,
        currentSkinRenderImage: Binding<NSImage?>,
        selectedCapeImage: Binding<NSImage?>,
        showSkinLibrary: Bool,
        onSkinDropped: @escaping (NSImage) -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        onSelectSkinLibraryItem: @escaping (SkinLibraryItem) -> Void,
        skinLibraryStore: SkinLibraryStore = SkinLibraryStore(),
    ) {
        _currentModel = currentModel
        _showingFileImporter = showingFileImporter
        _selectedSkinImage = selectedSkinImage
        _selectedSkinPath = selectedSkinPath
        _currentSkinRenderImage = currentSkinRenderImage
        _selectedCapeImage = selectedCapeImage
        self.showSkinLibrary = showSkinLibrary
        self.onSkinDropped = onSkinDropped
        self.onDrop = onDrop
        self.onSelectSkinLibraryItem = onSelectSkinLibraryItem
        self.skinLibraryStore = skinLibraryStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.upload".localized())
                .font(.headline)

            skinRenderArea

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drop skin file here or click to select")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("PNG 64×64 or legacy 64×32")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                Spacer()
                if showSkinLibrary {
                    Button("skin.library.title".localized()) {
                        showingSkinLibraryPopover = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(skinLibraryItems.isEmpty)
                    .popover(isPresented: $showingSkinLibraryPopover, arrowEdge: .trailing) {
                        SkinLibraryPopoverContentView(
                            items: skinLibraryItems,
                            isPresented: $showingSkinLibraryPopover,
                            onLoadMore: loadNextSkinLibraryPage,
                            onSelectItem: { item in
                                onSelectSkinLibraryItem(item)
                            },
                            onDeleteItem: { item in
                                pendingDeletion = item
                            },
                        )
                    }
                }
                Button {
                    openSkinPreviewWindow()
                } label: {
                    Image(systemName: "eye")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .disabled(selectedSkinImage == nil && currentSkinRenderImage == nil && selectedSkinPath == nil)
            }
        }
        .onAppear {
            if showSkinLibrary {
                resetSkinLibraryPagination()
            }
        }
        .deleteConfirmationDialog(
            pendingDeletion: $pendingDeletion,
            title: "skin.library.delete.history.title".localized(),
            message: { item in
                String(format: "skin.library.delete.history.message".localized(), item.displayName)
            },
            delete: { item in
                try? skinLibraryStore.deleteItem(item)
                skinLibraryItems.removeAll { $0.sha1 == item.sha1 }
                loadNextSkinLibraryPage()
            },
        )
    }

    private var skinRenderArea: some View {
        let playerModel = convertToPlayerModel(currentModel)
        let hasSkinRenderView = (selectedSkinImage != nil || currentSkinRenderImage != nil || selectedSkinPath != nil)

        return skinRenderContent(playerModel: playerModel)
            .frame(height: 220)
            .onTapGesture { showingFileImporter = true }
            .conditionalDrop(isEnabled: !hasSkinRenderView, perform: onDrop)
    }

    @ViewBuilder
    private func skinRenderContent(playerModel: PlayerModel) -> some View {
        if let image = selectedSkinImage ?? currentSkinRenderImage {
            SkinRenderView(
                skinImage: image,
                capeImage: $selectedCapeImage,
                playerModel: playerModel,
                rotationDuration: 0,
                backgroundColor: NSColor.clear,
                onSkinDropped: { dropped in
                    onSkinDropped(dropped)
                },
                onCapeDropped: { _ in },
            )
        } else if let skinPath = selectedSkinPath {
            SkinRenderView(
                texturePath: skinPath,
                capeImage: $selectedCapeImage,
                playerModel: playerModel,
                rotationDuration: 0,
                backgroundColor: NSColor.clear,
                onSkinDropped: { dropped in
                    onSkinDropped(dropped)
                },
                onCapeDropped: { _ in },
            )
        } else {
            Color.clear
        }
    }

    private func convertToPlayerModel(_ skinModel: PlayerSkinService.PublicSkinInfo.SkinModel) -> PlayerModel {
        switch skinModel {
        case .classic:
            return .steve
        case .slim:
            return .alex
        }
    }

    /// Opens a separate 3D skin preview window.
    private func openSkinPreviewWindow() {
        let playerModel = convertToPlayerModel(currentModel)
        let data = SkinPreviewData(
            skinImage: selectedSkinImage ?? currentSkinRenderImage,
            skinPath: selectedSkinPath,
            capeImage: selectedCapeImage,
            playerModel: playerModel,
        )
        container.ui.windowManager.preparePayload(data, for: .skinPreview)
        container.ui.windowManager.openWindow(id: .skinPreview)
    }

    /// Clears the loaded pages and fetches the first page from the database.
    private func resetSkinLibraryPagination() {
        skinLibraryItems = []
        skinLibraryCursor = nil
        skinLibraryHasMore = true
        loadNextSkinLibraryPage()
    }

    /// Fetches the next database page and appends it to the loaded items.
    ///
    /// Keyset pagination guarantees that pages never overlap, so appended items
    /// need no de-duplication. The store returns a non-empty page while
    /// `hasMore` is `true`, so the cursor always advances.
    private func loadNextSkinLibraryPage() {
        guard skinLibraryHasMore else { return }

        guard let page = try? skinLibraryStore.loadPage(
            after: skinLibraryCursor,
            limit: SkinLibraryStore.pageSize,
        ) else {
            skinLibraryHasMore = false
            return
        }

        skinLibraryItems.append(contentsOf: page.items)
        if let lastItem = page.items.last {
            skinLibraryCursor = lastItem
        }
        skinLibraryHasMore = page.hasMore
    }
}

extension View {
    @ViewBuilder
    func conditionalDrop(isEnabled: Bool, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if isEnabled {
            onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil, perform: perform)
        } else {
            self
        }
    }
}
