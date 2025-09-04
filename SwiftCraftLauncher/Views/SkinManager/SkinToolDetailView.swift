import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss)
    private var dismiss

    @State private var currentModel: PlayerSkinService.PublicSkinInfo.SkinModel = .classic
    @State private var showingFileImporter = false
    @State private var operationInProgress = false
    @State private var selectedSkinData: Data?
    @State private var selectedSkinImage: NSImage?
    @State private var selectedCapeId: String?
    @State private var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var playerProfile: MinecraftProfileResponse?
    @State private var isLoading = true
    @State private var hasChanges = false
    
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
                    ).id(player.avatarName)
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
                ContentUnavailableView("skin.no_player".localized(), systemImage: "person",
                    description: Text("skin.add_player_first".localized()))
            }
        }.frame(width: 280)
    }

    private var skinUploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("skin.upload".localized()).font(.headline)
            skinDropArea
        }
    }

    private var skinDropArea: some View {
        Group {
            if let image = selectedSkinImage {
                selectedSkinView(image: image)
            } else {
                emptyDropArea
            }
        }
        .onTapGesture { if selectedSkinData == nil { showingFileImporter = true } }
        .onDrop(of: [UTType.image.identifier], isTargeted: nil) { handleDrop($0) }
    }

    private func selectedSkinView(image: NSImage) -> some View {
        HStack(spacing: 12) {
            Image(nsImage: image)
                .resizable().interpolation(.none)
                .frame(width: 48, height: 48)
                .background(Color.gray.opacity(0.1)).cornerRadius(6)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("skin.selected".localized()).font(.callout).fontWeight(.medium)
                Text("skin.click_apply".localized()).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button("skin.remove".localized()) { clearSelectedSkin() }
                .buttonStyle(.plain).foregroundColor(.secondary).font(.caption)
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
        .background(emptyDropBackground)
    }

    private var selectedSkinBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.accentColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
    }

    private var emptyDropBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundColor(.secondary.opacity(0.5))
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
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func capeOption(id: String?, name: String, imageURL: String? = nil, isSystemOption: Bool = false) -> some View {
        let isSelected = selectedCapeId == id

        return Button { 
            selectedCapeId = id
            updateHasChanges()
        } label: {
            VStack(spacing: 6) {
                capeIconContainer(isSelected: isSelected, imageURL: imageURL, isSystemOption: isSystemOption)
                Text(name).font(.caption).lineLimit(1)
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
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                               lineWidth: isSelected ? 2 : 1)
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
                self.updateHasChanges()
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
                processSkinData(data)
            } catch {
                Logger.shared.error("Failed to read skin file: \(error)")
            }
        case .failure(let error):
            Logger.shared.error("File selection failed: \(error)")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
            guard let data = data else { return }
            DispatchQueue.main.async {
                self.processSkinData(data)
            }
        }
        return true
    }

    private func processSkinData(_ data: Data) {
        guard data.isPNG else { return }
        selectedSkinData = data
        selectedSkinImage = NSImage(data: data)
        updateHasChanges()
    }

    private func clearSelectedSkin() {
        selectedSkinData = nil
        selectedSkinImage = nil
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
            let result = await PlayerSkinService.uploadSkinAndRefresh(
                imageData: skinData,
                model: currentModel,
                player: player
            )
            return result
        } else if let original = originalModel, currentModel != original {
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
                        .resizable().interpolation(.none)
                        .frame(width: 64.0 * scale, height: 32.0 * scale)
                        .offset(x: offsetX, y: offsetY).clipped()
                }
            case .failure(_):
                Image(systemName: "photo").font(.system(size: 16)).foregroundColor(.secondary)
            @unknown default:
                Image(systemName: "photo").font(.system(size: 16)).foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SkinToolDetailView()
        .environmentObject(PlayerListViewModel())
        .environmentObject(SkinSelectionStore())
}
