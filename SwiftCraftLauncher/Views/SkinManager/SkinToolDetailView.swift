import SwiftUI
import UniformTypeIdentifiers

struct SkinToolDetailView: View {
    @EnvironmentObject var playerListViewModel: PlayerListViewModel
    @EnvironmentObject var skinSelection: SkinSelectionStore
    @State private var currentModel: SkinModelType = .classic
    @State private var showingFileImporter = false
    @State private var uploadInProgress = false
    @State private var selectedFileURL: URL?

    enum SkinModelType: String, CaseIterable, Identifiable { case classic, slim; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                previewSection
                modelSelectSection
                uploadSection
                Spacer(minLength: 20)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
        }
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
