import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SkinRenderKit

@MainActor
final class SkinToolDetailViewModel: ObservableObject {

    private let preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    private let preloadedProfile: MinecraftProfileResponse?

    init(
        preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?,
        preloadedProfile: MinecraftProfileResponse?
    ) {
        self.preloadedSkinInfo = preloadedSkinInfo
        self.preloadedProfile = preloadedProfile
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
    private var lastSelectedSkinData: Data?
    private var lastCurrentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    private var lastSelectedCapeId: String?
    private var lastCurrentActiveCapeId: String?

    // MARK: - Tasks
    private var loadCapeTask: Task<Void, Never>?
    private var loadSkinImageTask: Task<Void, Never>?
    private var downloadCapeTask: Task<Void, Never>?
    private var resetSkinTask: Task<Void, Never>?
    private var applyChangesTask: Task<Void, Never>?

    // MARK: - Derived
    private var currentActiveCapeId: String? {
        PlayerSkinService.getActiveCapeId(from: playerProfile)
    }

    private var originalModel: PlayerSkinService.PublicSkinInfo.SkinModel? {
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

    // MARK: - 当前皮肤渲染图

    func loadCurrentSkinRenderImageIfNeeded(resolvedPlayer: Player?) {
        if selectedSkinImage != nil || selectedSkinPath != nil { return }
        guard let urlString = publicSkinInfo?.skinURL?.httpToHttps(),
              let url = URL(string: urlString) else { return }

        loadSkinImageTask?.cancel()
        loadSkinImageTask = Task {
            do {
                let p = self.playerWithCredentialIfNeeded(resolvedPlayer)
                var headers: [String: String]?
                if let t = p?.authAccessToken, !t.isEmpty {
                    headers = ["Authorization": "Bearer \(t)"]
                } else {
                    headers = nil
                }
                let data = try await APIClient.get(url: url, headers: headers)
                guard !data.isEmpty, let image = NSImage(data: data) else { return }
                try Task.checkCancellation()
                self.currentSkinRenderImage = image
            } catch is CancellationError {
            } catch {
                Logger.shared.error("Failed to load current skin image for renderer: \(error)")
            }
        }
    }

    // MARK: - File Import & Drop

    func handleSkinDroppedImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            Logger.shared.error("Failed to convert dropped image to PNG data")
            return
        }

        guard data.isPNG else {
            Logger.shared.error("Converted data is not valid PNG format")
            return
        }

        selectedSkinData = data
        selectedSkinImage = image
        Task {
            let path = await Task.detached(priority: .userInitiated) {
                self.saveTempSkinFile(data: data)?.path
            }.value
            self.selectedSkinPath = path
            self.updateHasChanges()
        }

        Logger.shared.info("Skin image dropped and processed successfully. Model: \(currentModel.rawValue)")
    }

    func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }

            let urlForBackground = url
            Task {
                let data = await Task.detached(priority: .userInitiated) {
                    try? Data(contentsOf: urlForBackground)
                }.value
                urlForBackground.stopAccessingSecurityScopedResource()
                if let data = data {
                    self.processSkinData(data, filePath: urlForBackground.path)
                } else {
                    Logger.shared.error("Failed to read skin file")
                }
            }
        case .failure(let error):
            Logger.shared.error("File selection failed: \(error)")
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data = data else { return }
            Task {
                let tempURL = await Task.detached(priority: .userInitiated) { () -> URL? in
                    let tempDir = FileManager.default.temporaryDirectory
                    let fileName = "temp_skin_\(UUID().uuidString).png"
                    let tempURL = tempDir.appendingPathComponent(fileName)
                    do {
                        try data.write(to: tempURL)
                        return tempURL
                    } catch {
                        Logger.shared.error("Failed to save temporary skin file: \(error)")
                        return nil
                    }
                }.value
                self.processSkinData(data, filePath: tempURL?.path)
            }
        }
        return true
    }

    private func processSkinData(_ data: Data, filePath: String? = nil) {
        guard data.isPNG else { return }
        selectedSkinData = data
        selectedSkinImage = NSImage(data: data)
        selectedSkinPath = filePath
        updateHasChanges()
    }

    nonisolated private func saveTempSkinFile(data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "temp_skin_\(UUID().uuidString).png"
        let tempURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            Logger.shared.error("Failed to save temporary skin file: \(error)")
            return nil
        }
    }

    func clearSelectedSkin() {
        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false
        updateHasChanges()
    }

    // MARK: - Cape Selection

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

    // MARK: - Apply & Reset

    func resetSkin(resolvedPlayer: Player?) {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        resetSkinTask?.cancel()
        resetSkinTask = Task {
            do {
                let success = await PlayerSkinService.resetSkinAndRefresh(player: player)
                try Task.checkCancellation()

                self.operationInProgress = false
                if success {
                    // 由外部关闭视图
                }
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

    func applyChanges(resolvedPlayer: Player?, onAllSuccess: @escaping () -> Void) {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        applyChangesTask?.cancel()
        applyChangesTask = Task {
            do {
                let skinSuccess = await self.handleSkinChanges(player: player)
                try Task.checkCancellation()
                let capeSuccess = await self.handleCapeChanges(player: player)
                try Task.checkCancellation()

                self.operationInProgress = false
                if skinSuccess && capeSuccess {
                    onAllSuccess()
                }
            } catch is CancellationError {
                self.operationInProgress = false
            } catch {
                self.operationInProgress = false
            }
        }
    }

    private func handleSkinChanges(player: Player) async -> Bool {
        do {
            try Task.checkCancellation()

            if let skinData = selectedSkinData {
                let result = await PlayerSkinService.uploadSkinAndRefresh(
                    imageData: skinData,
                    model: currentModel,
                    player: player
                )
                try Task.checkCancellation()
                if result {
                    Logger.shared.info("Skin upload successful with model: \(currentModel.rawValue)")
                } else {
                    Logger.shared.error("Skin upload failed")
                }
                return result
            } else if let original = originalModel, currentModel != original {
                if let currentSkinInfo = publicSkinInfo, let skinURL = currentSkinInfo.skinURL {
                    let result = await uploadCurrentSkinWithNewModel(skinURL: skinURL, player: player)
                    try Task.checkCancellation()
                    return result
                } else {
                    return false
                }
            } else if originalModel == nil && currentModel != .classic {
                return false
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            Logger.shared.error("Skin changes error: \(error)")
            return false
        }
    }

    private func handleCapeChanges(player: Player) async -> Bool {
        do {
            try Task.checkCancellation()

            if selectedCapeId != currentActiveCapeId {
                try Task.checkCancellation()
                if let capeId = selectedCapeId {
                    let result = await PlayerSkinService.showCape(capeId: capeId, player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            self.playerProfile = newProfile
                            self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            self.updateHasChanges()
                        }
                    }
                    return result
                } else {
                    let result = await PlayerSkinService.hideCape(player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            self.playerProfile = newProfile
                            self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                            self.updateHasChanges()
                        }
                    }
                    return result
                }
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            return false
        }
    }

    private func uploadCurrentSkinWithNewModel(skinURL: String, player: Player) async -> Bool {
        do {
            try Task.checkCancellation()
            let p = playerWithCredentialIfNeeded(player) ?? player

            let httpsURL = skinURL.httpToHttps()

            guard let url = URL(string: httpsURL) else {
                return false
            }
            var headers: [String: String]?
            if !p.authAccessToken.isEmpty {
                headers = ["Authorization": "Bearer \(p.authAccessToken)"]
            } else {
                headers = nil
            }
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            let result = await PlayerSkinService.uploadSkin(
                imageData: data,
                model: currentModel,
                player: p
            )
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            return false
        } catch {
            Logger.shared.error("Failed to re-upload skin with new model: \(error)")
            return false
        }
    }

    // MARK: - 清除数据

    func clearAllData() {
        loadCapeTask?.cancel()
        loadSkinImageTask?.cancel()
        downloadCapeTask?.cancel()
        resetSkinTask?.cancel()
        applyChangesTask?.cancel()

        loadCapeTask = nil
        loadSkinImageTask = nil
        downloadCapeTask = nil
        resetSkinTask = nil
        applyChangesTask = nil

        deleteTemporaryFiles()

        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false

        selectedCapeId = nil
        selectedCapeImageURL = nil
        selectedCapeLocalPath = nil
        selectedCapeImage = nil
        isCapeLoading = false
        capeLoadCompleted = false

        publicSkinInfo = nil
        playerProfile = nil
        currentSkinRenderImage = nil

        currentModel = .classic
        hasChanges = false
        operationInProgress = false

        lastSelectedSkinData = nil
        lastCurrentModel = .classic
        lastSelectedCapeId = nil
        lastCurrentActiveCapeId = nil
    }

    private func deleteTemporaryFiles() {
        let fileManager = FileManager.default

        if let skinPath = selectedSkinPath, !skinPath.isEmpty {
            let skinURL = URL(fileURLWithPath: skinPath)
            if skinURL.path.hasPrefix(fileManager.temporaryDirectory.path) {
                do {
                    try fileManager.removeItem(at: skinURL)
                    Logger.shared.info("Deleted temporary skin file: \(skinPath)")
                } catch {
                    Logger.shared.warning("Failed to delete temporary skin file: \(error.localizedDescription)")
                }
            }
        }

        if let capePath = selectedCapeLocalPath, !capePath.isEmpty {
            let capeURL = URL(fileURLWithPath: capePath)
            if capeURL.path.hasPrefix(fileManager.temporaryDirectory.path) {
                do {
                    try fileManager.removeItem(at: capeURL)
                } catch {
                    Logger.shared.warning("Failed to delete temporary cape file: \(error.localizedDescription)")
                }
            }
        }
    }
}

