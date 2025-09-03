import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentModel: SkinModelType = .classic
    @State private var showingFileImporter = false
    @State private var operationInProgress = false
    @State private var selectedSkinData: Data?
    @State private var selectedSkinImage: NSImage?
    @State private var selectedCapeId: String?
    @State private var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var playerProfile: MinecraftProfileResponse?
    @State private var isLoading = true

    enum SkinModelType: String, CaseIterable {
        case classic, slim
    }

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
                            set: { currentModel = $0 ? .slim : .classic }
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
        
        return Button { selectedCapeId = id } label: {
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
    
    private var hasChanges: Bool {
        let hasSkinData = selectedSkinData != nil
        let hasCapeChange = selectedCapeId != currentActiveCapeId
        let hasModelChange = currentModel != originalModel
        
        Logger.shared.info("hasChanges check: skinData=\(hasSkinData), capeChange=\(hasCapeChange), modelChange=\(hasModelChange) (current=\(currentModel), original=\(originalModel))")
        
        return hasSkinData || hasCapeChange || hasModelChange
    }
    
    private var currentActiveCapeId: String? {
        playerProfile?.capes?.first { $0.state == "ACTIVE" }?.id
    }
    
    private var originalModel: SkinModelType {
        guard let model = publicSkinInfo?.model else { return .classic }
        return model == .classic ? .classic : .slim
    }
    
    private var currentSkinModel: PlayerSkinService.PublicSkinInfo.SkinModel {
        currentModel == .classic ? .classic : .slim
    }
    
    private func loadData() {
        guard let player = resolvedPlayer else { 
            Logger.shared.warning("No player selected for skin manager")
            isLoading = false
            return
        }

        Logger.shared.info("Loading skin data for player: \(player.name)")
        
        Task {
            async let skinInfo = PlayerSkinService.fetchPublicSkin(uuid: player.id)
            async let profile = PlayerSkinService.fetchPlayerProfile(player: player)
            
            let (skin, playerProfile) = await (skinInfo, profile)
            
            Logger.shared.info("Loaded skin info: \(skin != nil ? "success" : "failed")")
            Logger.shared.info("Loaded player profile: \(playerProfile != nil ? "success" : "failed")")
            
            if let profile = playerProfile {
                Logger.shared.info("Player has \(profile.capes?.count ?? 0) capes")
            }

            await MainActor.run {
                self.publicSkinInfo = skin
                self.playerProfile = playerProfile
                if let model = skin?.model {
                    self.currentModel = model == .classic ? .classic : .slim
                    Logger.shared.info("Loaded skin model: \(model) -> currentModel: \(self.currentModel)")
                } else {
                    self.currentModel = .classic // 默认使用 classic 模型
                    Logger.shared.info("No skin model found, using default: \(self.currentModel)")
                }
                self.selectedCapeId = currentActiveCapeId
                self.isLoading = false
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
    }
    
    private func clearSelectedSkin() {
        selectedSkinData = nil
        selectedSkinImage = nil
    }
    
    private func resetSkin() {
        guard let player = resolvedPlayer else { return }
        
        operationInProgress = true
        isLoading = true
        Task {
            let success = await PlayerSkinService.resetSkin(player: player)
            
            await MainActor.run {
                operationInProgress = false
                if success {
                    clearSelectedSkin()
                    refreshPlayerSkinInList()
                    loadData() // 重新加载数据
                } else {
                    isLoading = false
                }
            }
        }
    }
    
    private func refreshPlayerSkinInList() {
        guard let player = resolvedPlayer else { return }
        
        Task {
            if let skinInfo = await PlayerSkinService.fetchPublicSkin(uuid: player.id) {
                Logger.shared.info("Refreshing player skin: oldURL=\(player.avatarName), newURL=\(skinInfo.skinURL ?? "")")
                
                let updatedPlayer = try Player(
                    name: player.name,
                    uuid: player.id,
                    isOnlineAccount: player.isOnlineAccount,
                    avatarName: skinInfo.skinURL ?? "",
                    authXuid: player.authXuid,
                    authAccessToken: player.authAccessToken,
                    authRefreshToken: player.authRefreshToken,
                    tokenExpiresAt: player.tokenExpiresAt,
                    createdAt: player.createdAt,
                    lastPlayed: player.lastPlayed,
                    isCurrent: player.isCurrent,
                    gameRecords: player.gameRecords
                )
                
                await MainActor.run {
                    playerListViewModel.updatePlayerInList(updatedPlayer)
                    Logger.shared.info("Player skin updated in list")
                }
            } else {
                Logger.shared.warning("Failed to fetch updated skin info")
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
                    refreshPlayerSkinInList()
                    isLoading = true
                    loadData()
                    dismiss()
                }
            }
        }
    }
    
    private func handleSkinChanges(player: Player) async -> Bool {
        Logger.shared.info("handleSkinChanges: currentModel=\(currentModel), originalModel=\(originalModel)")
        Logger.shared.info("selectedSkinData: \(selectedSkinData != nil ? "has data" : "nil")")
        Logger.shared.info("publicSkinInfo: \(publicSkinInfo != nil ? "has info" : "nil")")
        Logger.shared.info("skinURL: \(publicSkinInfo?.skinURL ?? "nil")")
        
        if let skinData = selectedSkinData {
            Logger.shared.info("Uploading new skin with model: \(currentSkinModel)")
            let result = await PlayerSkinService.uploadSkin(
                imageData: skinData,
                model: currentSkinModel,
                player: player
            )
            Logger.shared.info("New skin upload result: \(result)")
            return result
        } else if currentModel != originalModel {
            Logger.shared.info("Changing skin model from \(originalModel) to \(currentModel)")
            if let currentSkinInfo = publicSkinInfo, let skinURL = currentSkinInfo.skinURL {
                let result = await uploadCurrentSkinWithNewModel(skinURL: skinURL, player: player)
                Logger.shared.info("Model change upload result: \(result)")
                return result
            } else {
                Logger.shared.warning("Cannot change skin model: no existing skin found")
                Logger.shared.warning("publicSkinInfo: \(publicSkinInfo != nil ? "exists" : "nil")")
                return false
            }
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
            Logger.shared.info("uploadCurrentSkinWithNewModel: skinURL=\(skinURL), model=\(currentSkinModel)")
            guard let url = URL(string: skinURL) else { 
                Logger.shared.error("Invalid skin URL: \(skinURL)")
                return false 
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            Logger.shared.info("Downloaded skin data: \(data.count) bytes")
            
            let result = await PlayerSkinService.uploadSkin(
                imageData: data,
                model: currentSkinModel,
                player: player
            )
            Logger.shared.info("Upload result: \(result)")
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
