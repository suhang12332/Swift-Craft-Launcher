import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SkinRenderKit

@MainActor
final class SkinToolDetailViewModel: ObservableObject {
    let skinLibraryStore: SkinLibraryStore

    let preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    let preloadedProfile: MinecraftProfileResponse?

    init(
        preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?,
        preloadedProfile: MinecraftProfileResponse?,
        skinLibraryStore: SkinLibraryStore = SkinLibraryStore()
    ) {
        self.preloadedSkinInfo = preloadedSkinInfo
        self.preloadedProfile = preloadedProfile
        self.skinLibraryStore = skinLibraryStore
    }

    @Published var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    @Published var showingFileImporter = false
    @Published var operationInProgress = false

    @Published var selectedSkinData: Data?
    @Published var selectedSkinImage: NSImage?
    @Published var selectedSkinPath: String?
    @Published var showingSkinPreview = false

    @Published var selectedCapeId: String?
    @Published var selectedCapeImageURL: String?
    @Published var selectedCapeLocalPath: String?
    @Published var selectedCapeImage: NSImage?
    @Published var isCapeLoading: Bool = false
    @Published var capeLoadCompleted: Bool = false

    @Published var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @Published var playerProfile: MinecraftProfileResponse?

    @Published var hasChanges = false
    @Published var currentSkinRenderImage: NSImage?

    // MARK: - 缓存
    var lastSelectedSkinData: Data?
    var lastCurrentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    var lastSelectedCapeId: String?
    var lastCurrentActiveCapeId: String?

    // MARK: - Tasks
    var loadCapeTask: Task<Void, Never>?
    var loadSkinImageTask: Task<Void, Never>?
    var downloadCapeTask: Task<Void, Never>?
    var resetSkinTask: Task<Void, Never>?
    var applyChangesTask: Task<Void, Never>?

    // MARK: - Derived
    var currentActiveCapeId: String? {
        PlayerSkinService.getActiveCapeId(from: playerProfile)
    }

    var originalModel: PlayerSkinService.PublicSkinInfo.SkinModel? {
        publicSkinInfo?.model
    }

    // MARK: - Lifecycle (给 View 调用)
    func onAppear(resolvedPlayer: Player?) -> Bool {
        guard let skinInfo = preloadedSkinInfo, let profile = preloadedProfile else {
            return false
        }

        publicSkinInfo = skinInfo
        playerProfile = profile
        currentModel = skinInfo.model
        selectedCapeId = PlayerSkinService.getActiveCapeId(from: profile)

        isCapeLoading = false
        capeLoadCompleted = false

        loadCurrentSkinRenderImageIfNeeded(resolvedPlayer: resolvedPlayer)

        loadCapeTask?.cancel()
        loadCapeTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.loadCurrentActiveCapeIfNeeded(from: profile, resolvedPlayer: resolvedPlayer)
        }

        updateHasChanges()
        return true
    }

    func onDisappear() {
        clearAllData()
    }

    // MARK: - Player & State

    func playerWithCredentialIfNeeded(_ player: Player?) -> Player? {
        guard let p = player, p.isOnlineAccount else { return player }
        var copy = p
        if copy.credential == nil {
            if let c = PlayerDataManager().loadCredential(userId: p.id) {
                copy.credential = c
            }
        }
        return copy
    }

    // MARK: - 状态变更

    func updateHasChanges() {
        let skinDataChanged = selectedSkinData != lastSelectedSkinData
        let modelChanged = currentModel != lastCurrentModel
        let capeIdChanged = selectedCapeId != lastSelectedCapeId
        let activeCapeIdChanged = currentActiveCapeId != lastCurrentActiveCapeId

        if !skinDataChanged && !modelChanged && !capeIdChanged && !activeCapeIdChanged {
            return
        }

        lastSelectedSkinData = selectedSkinData
        lastCurrentModel = currentModel
        lastSelectedCapeId = selectedCapeId
        lastCurrentActiveCapeId = currentActiveCapeId

        let hasSkinChange = PlayerSkinService.hasSkinChanges(
            selectedSkinData: selectedSkinData,
            currentModel: currentModel,
            originalModel: originalModel
        )
        let hasCapeChange = PlayerSkinService.hasCapeChanges(
            selectedCapeId: selectedCapeId,
            currentActiveCapeId: currentActiveCapeId
        )

        hasChanges = hasSkinChange || hasCapeChange
    }

    func handleCapeSelection(id: String?, imageURL: String?, resolvedPlayer: Player?) {
        loadCapeTask?.cancel()
        loadCapeTask = nil

        if let imageURL = imageURL, id != nil {
            // 切换披风时立即清空旧图片，避免显示错误的预览图
            // 新图片会在异步下载完成后更新
            selectedCapeImage = nil
            downloadCapeTask?.cancel()
            downloadCapeTask = Task {
                isCapeLoading = true
                capeLoadCompleted = false
                await self.downloadCapeTextureAndSetImage(from: imageURL, resolvedPlayer: resolvedPlayer)
                isCapeLoading = false
                capeLoadCompleted = true
            }
        } else {
            selectedCapeLocalPath = nil
            selectedCapeImage = nil
            // 取消选择披风时，立即完成（因为没有披风需要加载）
            capeLoadCompleted = true
            isCapeLoading = false
        }
        updateHasChanges()
    }

    func selectSkinLibraryItem(_ item: SkinLibraryItem) {
        let fileURL = item.fileURL

        guard let image = NSImage(contentsOf: fileURL) else {
            Logger.shared.error("Failed to decode selected skin library image at path: \(fileURL.path)")
            return
        }

        currentSkinRenderImage = nil
        currentModel = item.model
        selectedSkinImage = nil
        selectedSkinPath = nil

        Task { @MainActor in
            await Task.yield()
            self.handleSkinDroppedImage(image)
        }
    }
}
