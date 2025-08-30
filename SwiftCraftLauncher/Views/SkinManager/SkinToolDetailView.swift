import SwiftUI
import UniformTypeIdentifiers

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var skinSelection: SkinSelectionStore
    @State private var currentModel: SkinModelType = .classic
    @State private var showingFileImporter = false
    @State private var uploadInProgress = false
    @State private var selectedFileURL: URL?

    @State private var publicSkinInfo: PlayerSkinService.PublicSkinInfo?
    @State private var loadingPublicSkin = false
    @State private var publicSkinError: String?

    enum SkinModelType: String, CaseIterable, Identifiable { case classic, slim; var id: String { rawValue } }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            previewSection
            fullPreviewSection
            modelSelectSection
            uploadSection
            Spacer(minLength: 20)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
    }

    // MARK: Sections
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("skin.manager.title".localized())
                .font(.title3.bold())
            Text("skin.manager.description".localized())
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("skin.manager.section.current".localized())
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                if let player = resolvedPlayer {
                    VStack(spacing: 12) {
                        MinecraftSkinUtils(type: player.isOnlineAccount ? .url : .asset, src: player.avatarName, size: 96)
                            .shadow(radius: 2)
                        Text(player.name).font(.headline)
                        Text(currentModel == .classic ? "Classic" : "Slim")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("skin.manager.no_player".localized(), systemImage: "person", description: Text("skin.manager.add_player_first".localized()))
                }
            }
            HStack {
                Button("skin.manager.reset".localized()) {
                    // TODO: reset to default skin
                    Logger.shared.info("Reset skin clicked")
                }.disabled(resolvedPlayer == nil)
                Spacer()
            }
        }
    }
    // Full skin preview section
    private var fullPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("skin.manager.section.preview".localized())
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.12))
                    .frame(height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                if resolvedPlayer == nil {
                    ContentUnavailableView("skin.manager.no_player".localized(), systemImage: "person", description: Text(""))
                } else {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4,4]))
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.08)))
                                .frame(width: 120, height: 120)
                            if loadingPublicSkin {
                                ProgressView().controlSize(.small)
                            } else if let info = publicSkinInfo, let url = info.skinURL {
                                RemoteRawSkinImage(urlString: url)
                                    .frame(width: 110, height: 110)
                                    .clipped()
                                    .shadow(radius: 1)
                            } else if let error = publicSkinError {
                                Text(error).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(4)
                            } else {
                                Text("skin.manager.preview.placeholder".localized())
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if let info = publicSkinInfo {
                                Text(info.model == .classic ? "Classic" : "Slim")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Button(action: { Task { await loadPublicSkin(force: true) } }) {
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.plain).help("skin.manager.preview.refresh".localized())
                        }
                    }
                }
            }
        }
        .onChange(of: resolvedPlayer?.id) { _ in Task { await loadPublicSkin(force: true) } }
        .task { await loadPublicSkin() }
    }

    private func loadPublicSkin(force: Bool = false) async {
        guard let player = resolvedPlayer else { return }
        if loadingPublicSkin { return } // Avoid duplicate
        if publicSkinInfo != nil && !force { return } // Already loaded and not forced refresh
        loadingPublicSkin = true
        publicSkinError = nil
        let info = await PlayerSkinService.fetchPublicSkin(uuid: player.id)
        await MainActor.run {
            self.publicSkinInfo = info
            self.loadingPublicSkin = false
            if info == nil { self.publicSkinError = "skin.manager.preview.load_failed".localized() }
            if let model = info?.model { self.currentModel = (model == .classic ? .classic : .slim) }
        }
    }

    private var modelSelectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("skin.manager.section.model".localized())
            HStack(spacing: 24) {
                ForEach(SkinModelType.allCases) { model in
                    modelCard(model)
                }
                Spacer()
            }
        }
    }

    private func modelCard(_ model: SkinModelType) -> some View {
        Button {
            currentModel = model
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(currentModel == model ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: currentModel == model ? 2 : 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(currentModel == model ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .frame(width: 120, height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                let w = geo.size.width
                                let bodyW: CGFloat = 40
                                let bodyH: CGFloat = 60
                                let armW: CGFloat = model == .classic ? 12 : 10
                                VStack(spacing: 0) {
                                    Spacer(minLength: 16)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.4))
                                            .frame(width: bodyW, height: bodyH)
                                        HStack(spacing: 4) {
                                            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.4)).frame(width: armW, height: bodyH * 0.9)
                                            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.4)).frame(width: armW, height: bodyH * 0.9)
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(width: w, height: geo.size.height)
                            }
                            .frame(height: 120)
                            Text(model == .classic ? "Classic" : "Slim")
                                .font(.subheadline)
                                .padding(.bottom, 4)
                        }
                    )
                if currentModel == model {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.accentColor, .white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("skin.manager.section.upload".localized())
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    VStack(spacing: 12) {
                        if let file = selectedFileURL {
                            Text(file.lastPathComponent)
                                .font(.callout)
                        } else {
                            Text("skin.manager.upload.placeholder".localized())
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Button {
                            showingFileImporter = true
                        } label: {
                            Text(uploadInProgress ? "skin.manager.upload.uploading".localized() : "skin.manager.upload.select".localized())
                        }
                        .disabled(uploadInProgress || resolvedPlayer == nil)
                    }
                }
                Text("skin.manager.upload.note".localized())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.png]) { result in
            switch result {
            case .success(let url):
                selectedFileURL = url
                Logger.shared.info("Selected skin file: \(url.path)")
            case .failure(let error):
                Logger.shared.error("Selected skin file failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Helpers
    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.bottom, 4)
    }
}

// Original full skin rendering (no cropping, only displays 64x64 PNG)
private struct RemoteRawSkinImage: View {
    let urlString: String
    @State private var image: NSImage?
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        Group {
            if let image = image { Image(nsImage: image).resizable().interpolation(.none) }
            else { ProgressView().controlSize(.mini) }
        }
        .onAppear { load() }
        .onDisappear { task?.cancel() }
    }
    private func load() {
        task?.cancel()
        task = Task {
            guard let url = URL(string: urlString) else { return }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200, let ns = NSImage(data: data) else { return }
                await MainActor.run { self.image = ns }
                Logger.shared.debug("[RemoteRawSkinImage] Downloaded skin image bytes=\(data.count) url=\(urlString)")
            } catch {
                Logger.shared.error("[RemoteRawSkinImage] Download failed url=\(urlString) error=\(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SkinToolDetailView()
        .environmentObject(PlayerListViewModel())
}

// MARK: - Derived
extension SkinToolDetailView {
    var resolvedPlayer: Player? {
        if let id = skinSelection.selectedPlayerId,
           let p = playerListViewModel.players.first(where: { $0.id == id }) { return p }
        return playerListViewModel.currentPlayer
    }
}
