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
                    playerSection
                    skinUploadSection
                    capeSection
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

    private var playerSection: some View {
        VStack(spacing: 16) {
            if let player = resolvedPlayer {
                VStack(spacing: 12) {
                    MinecraftSkinUtils(
                        type: player.isOnlineAccount ? .url : .asset,
                        src: player.avatarName,
                        size: 88
                    )
                    Text(player.name).font(.title2.bold())

                    HStack(spacing: 4) {
                        Text("skin.classic".localized())
                            .font(.caption)
                            .foregroundColor(currentModel == .classic ? .primary : .secondary)

                        Toggle(isOn: Binding(
                            get: { currentModel == .slim },
                            set: {
                                currentModel = $0 ? .slim : .classic
                                updateHasChanges()
                            }
                        )) {
                            EmptyView() // 避免 "" 带来的多余空间
                        }
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                        .controlSize(.mini)

                        Text("skin.slim".localized())
                            .font(.caption)
                            .foregroundColor(currentModel == .slim ? .primary : .secondary)
                    }
                }
            } else {
                ContentUnavailableView(
                    "skin.no_player".localized(),
                    systemImage: "person",
                    description: Text("skin.add_player_first".localized())
                )
            }
        }.frame(width: 280)
    }

    private var skinUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.upload".localized()).font(.headline)

            skinRenderArea

            VStack(alignment: .leading, spacing: 4) {
                Text("Drop skin file here or click to select")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("PNG 64×64 or legacy 64×32")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private var skinRenderArea: some View {
        let playerModel = convertToPlayerModel(currentModel)

        return ZStack {
            Group {
                if let image = selectedSkinImage ?? currentSkinRenderImage {
                    SkinRenderView(
                        skinImage: image,
                        capeImage: nil,
                        playerModel: playerModel,
                        rotationDuration: 12.0,
                        backgroundColor: .clear,
                        onSkinDropped: { dropped in
                            handleSkinDroppedImage(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else if let skinPath = selectedSkinPath {
                    SkinRenderView(
                        texturePath: skinPath,
                        capeTexturePath: selectedCapeLocalPath,
                        playerModel: playerModel,
                        rotationDuration: 12.0,
                        backgroundColor: .clear,
                        onSkinDropped: { dropped in
                            handleSkinDroppedImage(dropped)
                        },
                        onCapeDropped: { _ in }
                    )
                } else {
                    Color.clear
                }
            }
            .frame(height: 220)
            .background(Color.gray.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundColor(.gray.opacity(0.35))
            )
            .cornerRadius(10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .onTapGesture { showingFileImporter = true }
        .onDrop(of: [UTType.image.identifier, UTType.fileURL.identifier], isTargeted: nil) { handleDrop($0) }
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

    private func selectedSkinView(image: NSImage) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 48, height: 48)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                VStack(alignment: .leading, spacing: 4) {
                    Text("skin.selected".localized()).font(.callout).fontWeight(.medium)
                    Text("skin.click_apply".localized()).font(.caption).foregroundColor(.secondary)
                }
                Spacer()

                Button("skin.preview_3d".localized()) {
                    showingSkinPreview = true
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .font(.caption)

                Button("skin.remove".localized()) { clearSelectedSkin() }
                    .buttonStyle(.plain).foregroundColor(.secondary).font(.caption)
            }

            if showingSkinPreview {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("skin.3d_preview".localized())
                            .font(.headline)
                        Spacer()
                        Button("skin.hide_preview".localized()) {
                            showingSkinPreview = false
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }

                    if let skinPath = selectedSkinPath {
                        SkinRenderView(
                            texturePath: skinPath,
                            capeTexturePath: selectedCapeLocalPath,
                            playerModel: convertToPlayerModel(currentModel)
                        )
                            .frame(height: 200)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(8)
                    } else {
                        Text("skin.preview_unavailable".localized())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(12)
        .background(selectedSkinBackground)
    }

    private var emptyDropArea: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 24)).foregroundColor(.secondary)
            Text("skin.drop_here".localized())
                .font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(emptyDropBackground())
    }

    private var selectedSkinBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.accentColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
    }

    private var capeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.cape".localized()).font(.headline)

            if let playerProfile = playerProfile, let capes = playerProfile.capes, !capes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        capeOption(id: nil, name: "skin.no_cape".localized(), isSystemOption: true)
                        ForEach(capes, id: \.id) { cape in
                            capeOption(id: cape.id, name: cape.alias ?? "skin.cape".localized(), imageURL: cape.url)
                        }
                    }.padding(4)
                }
            } else {
                Text("skin.no_capes_available".localized())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func capeOption(id: String?, name: String, imageURL: String? = nil, isSystemOption: Bool = false) -> some View {
        let isSelected = selectedCapeId == id

        return Button {
            selectedCapeId = id
            if let imageURL = imageURL, id != nil {
                selectedCapeImageURL = imageURL
                Task { await downloadCapeTextureIfNeeded(from: imageURL) }
            } else {
                selectedCapeImageURL = nil
                selectedCapeLocalPath = nil
            }
            updateHasChanges()
        } label: {
            VStack(spacing: 6) {
                capeIconContainer(isSelected: isSelected, imageURL: imageURL, isSystemOption: isSystemOption)
                Text(name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
        }.buttonStyle(.plain)
    }

    private func capeIconContainer(isSelected: Bool, imageURL: String?, isSystemOption: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 50, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

            if let imageURL = imageURL {
                CapeTextureView(imageURL: imageURL)
                    .frame(width: 42, height: 62).clipped().cornerRadius(6)
            } else if isSystemOption {
                Image(systemName: "xmark").font(.system(size: 16)).foregroundColor(.secondary)
            }
        }
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
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 { return }
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
            let (data, _) = try await URLSession.shared.data(from: url)

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

struct CapeTextureView: View {
    let imageURL: String

    var body: some View {
        AsyncImage(url: URL(string: imageURL.httpToHttps())) { phase in
            switch phase {
            case .empty:
                ProgressView().controlSize(.mini)
            case .success(let image):
                GeometryReader { geometry in
                    let containerWidth = geometry.size.width
                    let containerHeight = geometry.size.height
                    let capeAspectRatio: CGFloat = 10.0 / 16.0
                    let containerAspectRatio = containerWidth / containerHeight

                    let scale: CGFloat = containerAspectRatio > capeAspectRatio
                        ? containerHeight / 16.0
                        : containerWidth / 10.0

                    let offsetX = (containerWidth - 10.0 * scale) / 2.0 - 1.0 * scale
                    let offsetY = (containerHeight - 16.0 * scale) / 2.0 - 1.0 * scale

                    return image
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 64.0 * scale, height: 32.0 * scale)
                        .offset(x: offsetX, y: offsetY)
                        .clipped()
                }
            case .failure:
                Image(systemName: "photo").font(.system(size: 16)).foregroundColor(.secondary)
            @unknown default:
                Image(systemName: "photo").font(.system(size: 16)).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Cape Download Extension
extension SkinToolDetailView {
    fileprivate func downloadCapeTextureIfNeeded(from urlString: String) async {
        if let current = selectedCapeImageURL, current == urlString, selectedCapeLocalPath != nil {
            return
        }
        guard let url = URL(string: urlString.httpToHttps()) else {
            Logger.shared.error("Invalid cape URL: \(urlString)")
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                Logger.shared.error("Cape download failed: status=\(http.statusCode)")
                return
            }
            if data.isEmpty { return }
            let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("cape_\(UUID().uuidString).png")
            try data.write(to: tempFile)
            await MainActor.run {
                if selectedCapeImageURL == urlString {
                    selectedCapeLocalPath = tempFile.path
                }
            }
        } catch {
            Logger.shared.error("Cape download error: \(error)")
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
}

#Preview {
    SkinToolDetailView()
        .environmentObject(PlayerListViewModel())
        .environmentObject(SkinSelectionStore())
}
