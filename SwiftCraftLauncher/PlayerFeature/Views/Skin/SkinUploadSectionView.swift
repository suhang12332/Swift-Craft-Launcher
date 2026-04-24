import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit
import SkinRenderKit

struct SkinUploadSectionView: View {
    @Binding var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel
    @Binding var showingFileImporter: Bool
    @Binding var selectedSkinImage: NSImage?
    @Binding var selectedSkinPath: String?
    @Binding var currentSkinRenderImage: NSImage?
    @Binding var selectedCapeLocalPath: String?
    @Binding var selectedCapeImage: NSImage?
    @Binding var selectedCapeImageURL: String?
    @Binding var isCapeLoading: Bool
    @Binding var capeLoadCompleted: Bool
    @Binding var showingSkinPreview: Bool
    let showSkinLibrary: Bool
    @State private var showingSkinLibraryPopover = false
    @State private var skinLibraryItems: [SkinLibraryItem] = []
    @State private var pendingDeletion: SkinLibraryItem?

    let onSkinDropped: (NSImage) -> Void
    let onDrop: ([NSItemProvider]) -> Bool
    let onSelectSkinLibraryItem: (SkinLibraryItem) -> Void
    private let windowDataStore: WindowDataStore
    private let windowManager: WindowManager
    private let skinLibraryStore: SkinLibraryStore

    init(
        currentModel: Binding<PlayerSkinService.PublicSkinInfo.SkinModel>,
        showingFileImporter: Binding<Bool>,
        selectedSkinImage: Binding<NSImage?>,
        selectedSkinPath: Binding<String?>,
        currentSkinRenderImage: Binding<NSImage?>,
        selectedCapeLocalPath: Binding<String?>,
        selectedCapeImage: Binding<NSImage?>,
        selectedCapeImageURL: Binding<String?>,
        isCapeLoading: Binding<Bool>,
        capeLoadCompleted: Binding<Bool>,
        showingSkinPreview: Binding<Bool>,
        showSkinLibrary: Bool,
        onSkinDropped: @escaping (NSImage) -> Void,
        onDrop: @escaping ([NSItemProvider]) -> Bool,
        onSelectSkinLibraryItem: @escaping (SkinLibraryItem) -> Void,
        windowDataStore: WindowDataStore = AppServices.windowDataStore,
        windowManager: WindowManager = AppServices.windowManager,
        skinLibraryStore: SkinLibraryStore = SkinLibraryStore()
    ) {
        _currentModel = currentModel
        _showingFileImporter = showingFileImporter
        _selectedSkinImage = selectedSkinImage
        _selectedSkinPath = selectedSkinPath
        _currentSkinRenderImage = currentSkinRenderImage
        _selectedCapeLocalPath = selectedCapeLocalPath
        _selectedCapeImage = selectedCapeImage
        _selectedCapeImageURL = selectedCapeImageURL
        _isCapeLoading = isCapeLoading
        _capeLoadCompleted = capeLoadCompleted
        _showingSkinPreview = showingSkinPreview
        self.showSkinLibrary = showSkinLibrary
        self.onSkinDropped = onSkinDropped
        self.onDrop = onDrop
        self.onSelectSkinLibraryItem = onSelectSkinLibraryItem
        self.windowDataStore = windowDataStore
        self.windowManager = windowManager
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
                            onSelectItem: { item in
                                onSelectSkinLibraryItem(item)
                            },
                            onDeleteItem: { item in
                                pendingDeletion = item
                            }
                        )
                    }
                }
                Button {
                    openSkinPreviewWindow()
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                }
                .buttonStyle(.bordered)
                .disabled(selectedSkinImage == nil && currentSkinRenderImage == nil && selectedSkinPath == nil)
            }
        }
        .onAppear {
            if showSkinLibrary {
                reloadSkinLibraryItems()
            }
        }
        .confirmationDialog(
            "skin.library.delete.history.title".localized(),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { item in
            Button("common.delete".localized(), role: .destructive) {
                _ = skinLibraryStore.deleteItem(item)
                pendingDeletion = nil
                reloadSkinLibraryItems()
            }
            Button("skin.cancel".localized(), role: .cancel) {
                pendingDeletion = nil
            }
        } message: { item in
            Text(String(format: "skin.library.delete.history.message".localized(), item.displayName))
        }
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
        Group {
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
                    onCapeDropped: { _ in }
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
                    onCapeDropped: { _ in }
                )
            } else {
                Color.clear
            }
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

    /// 打开皮肤预览窗口
    private func openSkinPreviewWindow() {
        let playerModel = convertToPlayerModel(currentModel)
        // 存储到 WindowDataStore
        windowDataStore.skinPreviewData = SkinPreviewData(
            skinImage: selectedSkinImage ?? currentSkinRenderImage,
            skinPath: selectedSkinPath,
            capeImage: selectedCapeImage,
            playerModel: playerModel
        )
        // 打开窗口
        windowManager.openWindow(id: .skinPreview)
    }

    private func reloadSkinLibraryItems() {
        skinLibraryItems = skinLibraryStore.loadItems()
    }
}

// MARK: - View Extension for Conditional Drop
extension View {
    /// 条件性地应用拖拽处理修饰符
    @ViewBuilder
    func conditionalDrop(isEnabled: Bool, perform: @escaping ([NSItemProvider]) -> Bool) -> some View {
        if isEnabled {
            self.onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil, perform: perform)
        } else {
            self
        }
    }
}
