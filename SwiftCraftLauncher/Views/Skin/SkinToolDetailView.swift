import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SkinRenderKit

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    // 预加载的数据（可选）
    private let preloadedSkinInfo: PlayerSkinService.PublicSkinInfo?
    private let preloadedProfile: MinecraftProfileResponse?

    @State private var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    @State private var showingFileImporter = false
    @State private var operationInProgress = false
    @State private var selectedSkinData: Data?
    @State private var selectedSkinImage: NSImage?
    @State private var selectedSkinPath: String?
    @State private var showingSkinPreview = false
    @State private var selectedCapeId: String?
    @State private var selectedCapeImageURL: String?
    @State private var selectedCapeLocalPath: String?
    @State private var selectedCapeImage: NSImage?
    @State private var isCapeLoading: Bool = false
    @State private var capeLoadCompleted: Bool = false
    @State private var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var playerProfile: MinecraftProfileResponse?

    init(
        preloadedSkinInfo: PlayerSkinService.PublicSkinInfo? = nil,
        preloadedProfile: MinecraftProfileResponse? = nil
    ) {
        self.preloadedSkinInfo = preloadedSkinInfo
        self.preloadedProfile = preloadedProfile
    }

    @State private var hasChanges = false
    @State private var currentSkinRenderImage: NSImage?
    // 缓存之前的值，避免不必要的计算
    @State private var lastSelectedSkinData: Data?
    @State private var lastCurrentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    @State private var lastSelectedCapeId: String?
    @State private var lastCurrentActiveCapeId: String?

    // Task 引用管理，用于清理时取消所有异步任务
    @State private var loadCapeTask: Task<Void, Never>?
    @State private var loadSkinImageTask: Task<Void, Never>?
    @State private var downloadCapeTask: Task<Void, Never>?
    @State private var resetSkinTask: Task<Void, Never>?
    @State private var applyChangesTask: Task<Void, Never>?

    var body: some View {
        CommonSheetView(
            header: { headerView },
            body: { bodyContentView },
            footer: { footerView }
        )
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.png],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .onAppear {
            // 完全使用预加载的数据
            guard let skinInfo = preloadedSkinInfo, let profile = preloadedProfile else {
                dismiss()
                return
            }
            publicSkinInfo = skinInfo
            playerProfile = profile
            currentModel = skinInfo.model
            selectedCapeId = PlayerSkinService.getActiveCapeId(from: profile)

            // 初始化加载状态
            isCapeLoading = false
            capeLoadCompleted = false

            // 加载当前皮肤图片
            loadCurrentSkinRenderImageIfNeeded()

            // 立即加载当前激活的披风（使用高优先级任务）
            loadCapeTask?.cancel()
            loadCapeTask = Task<Void, Never>(priority: .userInitiated) {
                await loadCurrentActiveCapeIfNeeded(from: profile)
            }

            updateHasChanges()
        }
        .onDisappear {
            // 页面关闭后清除所有数据
            clearAllData()
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
                currentModel: $currentModel
            )
            .onChange(of: currentModel) { _, _ in
                updateHasChanges()
            }

            SkinUploadSectionView(
                currentModel: $currentModel,
                showingFileImporter: $showingFileImporter,
                selectedSkinImage: $selectedSkinImage,
                selectedSkinPath: $selectedSkinPath,
                currentSkinRenderImage: $currentSkinRenderImage,
                selectedCapeLocalPath: $selectedCapeLocalPath,
                selectedCapeImage: $selectedCapeImage,
                selectedCapeImageURL: $selectedCapeImageURL,
                isCapeLoading: $isCapeLoading,
                capeLoadCompleted: $capeLoadCompleted,
                showingSkinPreview: $showingSkinPreview,
                onSkinDropped: handleSkinDroppedImage,
                onDrop: handleDrop
            )

            CapeSelectionView(
                playerProfile: playerProfile,
                selectedCapeId: $selectedCapeId,
                selectedCapeImageURL: $selectedCapeImageURL,
                selectedCapeImage: $selectedCapeImage
            ) { id, imageURL in
                loadCapeTask?.cancel()
                loadCapeTask = nil

                if let imageURL = imageURL, id != nil {
                    // 切换披风时立即清空旧图片，避免显示错误的预览图
                    // 新图片会在异步下载完成后更新
                    selectedCapeImage = nil
                    downloadCapeTask?.cancel()
                    downloadCapeTask = Task<Void, Never> {
                        await MainActor.run {
                            isCapeLoading = true
                            capeLoadCompleted = false
                        }
                        await downloadCapeTextureAndSetImage(from: imageURL)
                        await MainActor.run {
                            isCapeLoading = false
                            capeLoadCompleted = true
                        }
                    }
                } else {
                    selectedCapeLocalPath = nil
                    // 调试日志：取消选择披风
                    // Logger.shared.info("[SkinToolDetailView] 设置 selectedCapeImage = nil (取消选择披风), id: \(id ?? "nil")")
                    selectedCapeImage = nil
                    // 取消选择披风时，立即完成（因为没有披风需要加载）
                    capeLoadCompleted = true
                    isCapeLoading = false
                }
                updateHasChanges()
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("skin.cancel".localized()) { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()

            HStack(spacing: 12) {
                if resolvedPlayer?.isOnlineAccount == true {
                    Button("skin.reset".localized()) { resetSkin() }.disabled(operationInProgress)
                }
                Button("skin.apply".localized()) { applyChanges() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(operationInProgress || !hasChanges)
            }
        }
    }

    private func handleSkinDroppedImage(_ image: NSImage) {
        // Convert NSImage to PNG Data
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            Logger.shared.error("Failed to convert dropped image to PNG data")
            return
        }

        // Validate PNG data
        guard data.isPNG else {
            Logger.shared.error("Converted data is not valid PNG format")
            return
        }

        selectedSkinData = data
        selectedSkinImage = image
        selectedSkinPath = saveTempSkinFile(data: data)?.path
        updateHasChanges()

        Logger.shared.info("Skin image dropped and processed successfully. Model: \(currentModel.rawValue)")
    }

    private var resolvedPlayer: Player? { playerListViewModel.currentPlayer }

    /// 在需要访问皮肤/披风等受保护资源时，确保玩家已从 Keychain 加载认证凭据（accessToken）
    private func playerWithCredentialIfNeeded(_ player: Player?) -> Player? {
        guard let p = player, p.isOnlineAccount else { return player }
        var copy = p
        if copy.credential == nil {
            if let c = PlayerDataManager().loadCredential(userId: p.id) {
                copy.credential = c
            }
        }
        return copy
    }

    private func updateHasChanges() {
        // 检查是否有任何相关值发生变化
        let skinDataChanged = selectedSkinData != lastSelectedSkinData
        let modelChanged = currentModel != lastCurrentModel
        let capeIdChanged = selectedCapeId != lastSelectedCapeId
        let activeCapeIdChanged = currentActiveCapeId != lastCurrentActiveCapeId

        // 如果没有任何变化，直接返回
        if !skinDataChanged && !modelChanged && !capeIdChanged && !activeCapeIdChanged {
            return
        }

        // 更新缓存的值
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

    private var currentActiveCapeId: String? {
        PlayerSkinService.getActiveCapeId(from: playerProfile)
    }

    private var originalModel: PlayerSkinService.PublicSkinInfo.SkinModel? {
        publicSkinInfo?.model
    }

    private func loadCurrentSkinRenderImageIfNeeded() {
        if selectedSkinImage != nil || selectedSkinPath != nil { return }
        guard let urlString = publicSkinInfo?.skinURL?.httpToHttps(), let url = URL(string: urlString) else { return }
        loadSkinImageTask?.cancel()
        loadSkinImageTask = Task<Void, Never> {
            do {
                let p = playerWithCredentialIfNeeded(resolvedPlayer)
                var headers: [String: String]?
                if let t = p?.authAccessToken, !t.isEmpty {
                    headers = ["Authorization": "Bearer \(t)"]
                } else {
                    headers = nil
                }
                let data = try await APIClient.get(url: url, headers: headers)
                guard !data.isEmpty, let image = NSImage(data: data) else { return }
                try Task.checkCancellation()
                await MainActor.run { self.currentSkinRenderImage = image }
            } catch is CancellationError {
                // 任务被取消，不需要处理
            } catch {
                Logger.shared.error("Failed to load current skin image for renderer: \(error)")
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                processSkinData(data, filePath: url.path)
            } catch {
                Logger.shared.error("Failed to read skin file: \(error)")
            }
        case .failure(let error):
            Logger.shared.error("File selection failed: \(error)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            guard let data = data else { return }
            DispatchQueue.main.async {
                let tempURL = self.saveTempSkinFile(data: data)
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

    private func saveTempSkinFile(data: Data) -> URL? {
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

    private func clearSelectedSkin() {
        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false
        updateHasChanges()
    }

    private func resetSkin() {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        resetSkinTask?.cancel()
        resetSkinTask = Task<Void, Never> {
            do {
                let success = await PlayerSkinService.resetSkinAndRefresh(player: player)
                try Task.checkCancellation()

                await MainActor.run {
                    operationInProgress = false
                    if success {
                        // 重置成功后关闭视图，由外部重新打开并传入新的预加载数据
                        dismiss()
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    operationInProgress = false
                }
            } catch {
                // 其他错误，重置状态
                await MainActor.run {
                    operationInProgress = false
                }
            }
        }
    }

    private func applyChanges() {
        guard let resolved = resolvedPlayer else { return }
        let player = playerWithCredentialIfNeeded(resolved) ?? resolved

        operationInProgress = true
        applyChangesTask?.cancel()
        applyChangesTask = Task<Void, Never> {
            do {
                let skinSuccess = await handleSkinChanges(player: player)
                try Task.checkCancellation()
                let capeSuccess = await handleCapeChanges(player: player)
                try Task.checkCancellation()

                await MainActor.run {
                    operationInProgress = false
                    if skinSuccess && capeSuccess {
                        dismiss()
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    operationInProgress = false
                }
            } catch {
                // 其他错误，重置状态
                await MainActor.run {
                    operationInProgress = false
                }
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
            return true // No skin changes needed
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
                        // 成功后刷新玩家资料，确保当前激活披风ID与服务器一致
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            await MainActor.run {
                                self.playerProfile = newProfile
                                self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                                self.updateHasChanges()
                            }
                        }
                    }
                    return result
                } else {
                    let result = await PlayerSkinService.hideCape(player: player)
                    try Task.checkCancellation()
                    if result {
                        if let newProfile = await PlayerSkinService.fetchPlayerProfile(player: player) {
                            await MainActor.run {
                                self.playerProfile = newProfile
                                self.selectedCapeId = PlayerSkinService.getActiveCapeId(from: newProfile)
                                self.updateHasChanges()
                            }
                        }
                    }
                    return result
                }
            }
            return true // No cape changes needed
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

            // 将HTTP URL转换为HTTPS以符合ATS策略
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
}

extension Data {
    var isPNG: Bool {
        self.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }
}

// MARK: - Cape Download Extension
extension SkinToolDetailView {
    /// 加载当前激活的披风（如果存在）
    private func loadCurrentActiveCapeIfNeeded(from profile: MinecraftProfileResponse) async {
        do {
            try Task.checkCancellation()

            // 如果用户已经手动选择了与当前激活披风不同的披风，则不再加载「当前激活披风」以免覆盖预览
            if let manualSelectedId = selectedCapeId,
               let activeId = PlayerSkinService.getActiveCapeId(from: profile),
               manualSelectedId != activeId {
                return
            }

            // 优先检查 publicSkinInfo 中的 capeURL
            if let capeURL = publicSkinInfo?.capeURL, !capeURL.isEmpty {
                await MainActor.run {
                    selectedCapeImageURL = capeURL
                    isCapeLoading = true
                    capeLoadCompleted = false
                }
                try Task.checkCancellation()
                await downloadCapeTextureAndSetImage(from: capeURL)
                try Task.checkCancellation()
                await MainActor.run {
                    isCapeLoading = false
                    capeLoadCompleted = true
                }
                return
            }

            try Task.checkCancellation()

            // 否则从 profile 中查找激活的披风
            guard let activeCapeId = PlayerSkinService.getActiveCapeId(from: profile) else {
                await MainActor.run {
                    selectedCapeImageURL = nil
                    selectedCapeLocalPath = nil
                    selectedCapeImage = nil
                    isCapeLoading = false
                    capeLoadCompleted = true  // 没有披风，可以立即渲染皮肤
                }
                return
            }

            try Task.checkCancellation()

            guard let capes = profile.capes, !capes.isEmpty else {
                await MainActor.run {
                    selectedCapeImageURL = nil
                    selectedCapeLocalPath = nil
                    selectedCapeImage = nil
                    isCapeLoading = false
                    capeLoadCompleted = true  // 没有披风，可以立即渲染皮肤
                }
                return
            }

            try Task.checkCancellation()

            guard let activeCape = capes.first(where: { $0.id == activeCapeId && $0.state == "ACTIVE" }) else {
                await MainActor.run {
                    selectedCapeImageURL = nil
                    selectedCapeLocalPath = nil
                    selectedCapeImage = nil
                    isCapeLoading = false
                    capeLoadCompleted = true  // 没有激活的披风，可以立即渲染皮肤
                }
                return
            }

            try Task.checkCancellation()

            // 有披风需要加载，设置加载状态
            await MainActor.run {
                selectedCapeImageURL = activeCape.url
                isCapeLoading = true
                capeLoadCompleted = false
            }
            try Task.checkCancellation()
            await downloadCapeTextureAndSetImage(from: activeCape.url)
            try Task.checkCancellation()
            await MainActor.run {
                isCapeLoading = false
                capeLoadCompleted = true
            }
        } catch is CancellationError {
            // 任务被取消，重置状态
            await MainActor.run {
                isCapeLoading = false
                capeLoadCompleted = false
            }
        } catch {
            // 其他错误，重置状态并记录日志
            Logger.shared.error("Failed to load current active cape: \(error)")
            await MainActor.run {
                isCapeLoading = false
                capeLoadCompleted = false
            }
        }
    }

    fileprivate func downloadCapeTextureIfNeeded(from urlString: String) async {
        if let current = selectedCapeImageURL, current == urlString, selectedCapeLocalPath != nil {
            return
        }
        // 验证 URL 格式（但不保留 URL 对象，节省内存）
        guard URL(string: urlString.httpToHttps()) != nil else {
            return
        }
        do {
            // 使用 DownloadManager 下载文件（已包含所有优化）
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            _ = try await DownloadManager.downloadFile(
                urlString: urlString.httpToHttps(),
                destinationURL: tempFile,
                expectedSha1: nil
            )
            await MainActor.run {
                if selectedCapeImageURL == urlString {
                    selectedCapeLocalPath = tempFile.path
                }
            }
        } catch {
            Logger.shared.error("Cape download error: \(error)")
        }
    }

    /// 下载披风纹理并设置图片
    private func downloadCapeTextureAndSetImage(from urlString: String) async {
        // 检查是否已经下载过相同的URL
        if let currentURL = selectedCapeImageURL,
           currentURL == urlString,
           let currentPath = selectedCapeLocalPath,
           FileManager.default.fileExists(atPath: currentPath),
           let cachedImage = NSImage(contentsOfFile: currentPath) {
            try? Task.checkCancellation()
            await MainActor.run {
                selectedCapeImage = cachedImage
            }
            return
        }

        // 验证 URL 格式
        guard let url = URL(string: urlString.httpToHttps()) else {
            await MainActor.run {
                selectedCapeImage = nil
            }
            return
        }

        do {
            let p = playerWithCredentialIfNeeded(resolvedPlayer)
            var headers: [String: String]?
            if let t = p?.authAccessToken, !t.isEmpty {
                headers = ["Authorization": "Bearer \(t)"]
            } else {
                headers = nil
            }
            let data = try await APIClient.get(url: url, headers: headers)
            try Task.checkCancellation()

            guard !data.isEmpty, let image = NSImage(data: data) else {
                await MainActor.run {
                    selectedCapeImage = nil
                }
                return
            }

            try Task.checkCancellation()

            // 立即更新UI，不等待文件保存
            await MainActor.run {
                // 检查URL是否仍然匹配（防止用户快速切换）
                if selectedCapeImageURL == urlString {
                    selectedCapeImage = image
                }
            }

            try Task.checkCancellation()

            // 异步保存到临时文件（不阻塞UI更新）
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            do {
                try data.write(to: tempFile)
                try Task.checkCancellation()
                await MainActor.run {
                    if selectedCapeImageURL == urlString {
                        selectedCapeLocalPath = tempFile.path
                    }
                }
            } catch is CancellationError {
                // 如果任务被取消，删除刚创建的文件
                try? FileManager.default.removeItem(at: tempFile)
            } catch {
                Logger.shared.error("Failed to save cape to temp file: \(error)")
            }
        } catch is CancellationError {
            // 任务被取消，不需要处理
        } catch {
            Logger.shared.error("Cape download error: \(error.localizedDescription)")
        }
    }

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 取消所有正在运行的异步任务
        loadCapeTask?.cancel()
        loadSkinImageTask?.cancel()
        downloadCapeTask?.cancel()
        resetSkinTask?.cancel()
        applyChangesTask?.cancel()

        // 清理所有 Task 引用
        loadCapeTask = nil
        loadSkinImageTask = nil
        downloadCapeTask = nil
        resetSkinTask = nil
        applyChangesTask = nil

        // 删除临时文件
        deleteTemporaryFiles()

        // 清理选中的皮肤数据
        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false
        // 清理斗篷数据
        selectedCapeId = nil
        selectedCapeImageURL = nil
        selectedCapeLocalPath = nil
        selectedCapeImage = nil
        isCapeLoading = false
        capeLoadCompleted = false
        // 清理加载的数据
        publicSkinInfo = nil
        playerProfile = nil
        currentSkinRenderImage = nil
        // 重置状态
        currentModel = .classic
        hasChanges = false
        operationInProgress = false
        // 清理缓存的值
        lastSelectedSkinData = nil
        lastCurrentModel = .classic
        lastSelectedCapeId = nil
        lastCurrentActiveCapeId = nil
    }

    /// 删除创建的临时文件
    private func deleteTemporaryFiles() {
        let fileManager = FileManager.default

        // 删除临时皮肤文件
        if let skinPath = selectedSkinPath, !skinPath.isEmpty {
            let skinURL = URL(fileURLWithPath: skinPath)
            // 只删除临时目录中的临时文件
            if skinURL.path.hasPrefix(fileManager.temporaryDirectory.path) {
                do {
                    try fileManager.removeItem(at: skinURL)
                    Logger.shared.info("Deleted temporary skin file: \(skinPath)")
                } catch {
                    Logger.shared.warning("Failed to delete temporary skin file: \(error.localizedDescription)")
                }
            }
        }

        // 删除临时披风文件
        if let capePath = selectedCapeLocalPath, !capePath.isEmpty {
            let capeURL = URL(fileURLWithPath: capePath)
            // 只删除临时目录中的临时文件
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
