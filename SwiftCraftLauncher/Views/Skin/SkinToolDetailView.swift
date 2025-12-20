import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SkinRenderKit

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

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
    @State private var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var playerProfile: MinecraftProfileResponse?
    @State private var isLoading = true
    @State private var hasChanges = false
    @State private var currentSkinRenderImage: NSImage?
    // 缓存之前的值，避免不必要的计算
    @State private var lastSelectedSkinData: Data?
    @State private var lastCurrentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    @State private var lastSelectedCapeId: String?
    @State private var lastCurrentActiveCapeId: String?

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
            loadData()
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
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
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
                        showingSkinPreview: $showingSkinPreview,
                        onSkinDropped: handleSkinDroppedImage,
                        onDrop: handleDrop
                    )

                    CapeSelectionView(
                        playerProfile: playerProfile,
                        selectedCapeId: $selectedCapeId,
                        selectedCapeImageURL: $selectedCapeImageURL
                    ) { id, imageURL in
                        if let imageURL = imageURL, id != nil {
                            Task { await downloadCapeTextureIfNeeded(from: imageURL) }
                        } else {
                            selectedCapeLocalPath = nil
                        }
                        updateHasChanges()
                    }
                }
            }
        }
    }

    private var footerView: some View {
        HStack {
            Button("skin.cancel".localized()) { dismiss() }.keyboardShortcut(.cancelAction)
            Spacer()

            if !isLoading {
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

    private func loadData() {
        guard let player = resolvedPlayer else {
            Logger.shared.warning("No player selected for skin manager")
            isLoading = false
            return
        }

        Task {
            async let skinInfo = PlayerSkinService.fetchCurrentPlayerSkinFromServices(player: player)
            async let profile = PlayerSkinService.fetchPlayerProfile(player: player)

            let (skin, playerProfile) = await (skinInfo, profile)

            await MainActor.run {
                self.publicSkinInfo = skin
                self.playerProfile = playerProfile
                if let model = skin?.model {
                    self.currentModel = model
                } else {
                    self.currentModel = .classic // 默认使用 classic 模型
                }
                self.selectedCapeId = currentActiveCapeId
                self.isLoading = false
                self.loadCurrentSkinRenderImageIfNeeded()
                self.updateHasChanges()
            }
        }
    }

    private func loadCurrentSkinRenderImageIfNeeded() {
        if selectedSkinImage != nil || selectedSkinPath != nil { return }
        guard let urlString = publicSkinInfo?.skinURL?.httpToHttps(), let url = URL(string: urlString) else { return }
        Task {
            do {
                // 使用统一的 API 客户端
                let data = try await APIClient.get(url: url)
                guard !data.isEmpty, let image = NSImage(data: data) else { return }
                await MainActor.run { self.currentSkinRenderImage = image }
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
        guard let player = resolvedPlayer else { return }

        operationInProgress = true
        isLoading = true
        Task {
            let success = await PlayerSkinService.resetSkinAndRefresh(player: player)

            await MainActor.run {
                operationInProgress = false
                if success {
                    clearSelectedSkin()
                    loadData() // 重新加载数据
                } else {
                    isLoading = false
                }
            }
        }
    }

    private func applyChanges() {
        guard let player = resolvedPlayer else { return }

        operationInProgress = true
        Task {
            let skinSuccess = await handleSkinChanges(player: player)
            let capeSuccess = await handleCapeChanges(player: player)

            await MainActor.run {
                operationInProgress = false
                if skinSuccess && capeSuccess {
                    dismiss()
                }
            }
        }
    }

    private func handleSkinChanges(player: Player) async -> Bool {
        if let skinData = selectedSkinData {
            Logger.shared.info("Uploading new skin with model: \(currentModel.rawValue)")
            let result = await PlayerSkinService.uploadSkinAndRefresh(
                imageData: skinData,
                model: currentModel,
                player: player
            )
            if result {
                Logger.shared.info("Skin upload successful with model: \(currentModel.rawValue)")
            } else {
                Logger.shared.error("Skin upload failed")
            }
            return result
        } else if let original = originalModel, currentModel != original {
            Logger.shared.info("Changing skin model from \(original.rawValue) to \(currentModel.rawValue)")
            if let currentSkinInfo = publicSkinInfo, let skinURL = currentSkinInfo.skinURL {
                let result = await uploadCurrentSkinWithNewModel(skinURL: skinURL, player: player)
                return result
            } else {
                Logger.shared.warning("Cannot change skin model: no existing skin found")
                return false
            }
        } else if originalModel == nil && currentModel != .classic {
            Logger.shared.warning("Cannot set model without skin data. User needs to select a skin first.")
            return false
        }
        Logger.shared.info("No skin changes needed")
        return true // No skin changes needed
    }

    private func handleCapeChanges(player: Player) async -> Bool {
        if selectedCapeId != currentActiveCapeId {
            if let capeId = selectedCapeId {
                return await PlayerSkinService.showCape(capeId: capeId, player: player)
            } else {
                return await PlayerSkinService.hideCape(player: player)
            }
        }
        return true // No cape changes needed
    }

    private func uploadCurrentSkinWithNewModel(skinURL: String, player: Player) async -> Bool {
        do {
            // 将HTTP URL转换为HTTPS以符合ATS策略
            let httpsURL = skinURL.httpToHttps()

            guard let url = URL(string: httpsURL) else {
                Logger.shared.error("Invalid skin URL: \(httpsURL)")
                return false
            }
            // 使用统一的 API 客户端
            let data = try await APIClient.get(url: url)

            let result = await PlayerSkinService.uploadSkin(
                imageData: data,
                model: currentModel,
                player: player
            )
            return result
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
    fileprivate func downloadCapeTextureIfNeeded(from urlString: String) async {
        if let current = selectedCapeImageURL, current == urlString, selectedCapeLocalPath != nil {
            return
        }
        // 验证 URL 格式（但不保留 URL 对象，节省内存）
        guard URL(string: urlString.httpToHttps()) != nil else {
            Logger.shared.error("Invalid cape URL: \(urlString)")
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

    // MARK: - 清除数据
    /// 清除页面所有数据
    private func clearAllData() {
        // 清理选中的皮肤数据
        selectedSkinData = nil
        selectedSkinImage = nil
        selectedSkinPath = nil
        showingSkinPreview = false
        // 清理斗篷数据
        selectedCapeId = nil
        selectedCapeImageURL = nil
        selectedCapeLocalPath = nil
        // 清理加载的数据
        publicSkinInfo = nil
        playerProfile = nil
        currentSkinRenderImage = nil
        // 重置状态
        currentModel = .classic
        isLoading = true
        hasChanges = false
        operationInProgress = false
        // 清理缓存的值
        lastSelectedSkinData = nil
        lastCurrentModel = .classic
        lastSelectedCapeId = nil
        lastCurrentActiveCapeId = nil
    }
}

#Preview {
    SkinToolDetailView()
        .environmentObject(PlayerListViewModel())
        .environmentObject(SkinSelectionStore())
}
