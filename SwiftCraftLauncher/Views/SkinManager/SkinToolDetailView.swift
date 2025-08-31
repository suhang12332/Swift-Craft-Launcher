import Foundation
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

    // Cape management states
    @State private var playerProfile: MinecraftProfileResponse?
    @State private var loadingProfile = false
    @State private var capeOperationInProgress = false

    enum SkinModelType: String, CaseIterable, Identifiable {
        case classic, slim

        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            previewSection
            fullPreviewSection
            modelSelectSection
            capeSection
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
                    .frame(height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                if let player = resolvedPlayer {
                    VStack(spacing: 16) {
                        // Player name and account type
                        VStack(spacing: 4) {
                            Text(player.name)
                                .font(.title2.bold())
                                .foregroundColor(.primary)

                            HStack(spacing: 6) {
                                Image(
                                    systemName: player.isOnlineAccount
                                        ? "network" : "person.crop.circle"
                                )
                                .font(.caption)
                                .foregroundColor(
                                    player.isOnlineAccount ? .green : .orange
                                )
                                Text(
                                    player.isOnlineAccount
                                        ? "Online Account" : "Offline Account"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }

                        // Skin and Cape preview with enhanced layout
                        HStack(spacing: 24) {
                            // Skin preview with info
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 96, height: 96)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    Color.accentColor.opacity(
                                                        0.3
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    MinecraftSkinUtils(
                                        type: player.isOnlineAccount
                                            ? .url : .asset,
                                        src: player.avatarName,
                                        size: 88
                                    )
                                    .shadow(radius: 2)
                                }

                                VStack(spacing: 2) {
                                    Text("Skin")
                                        .font(.caption.bold())
                                        .foregroundColor(.primary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "person.fill")
                                            .font(.caption2)
                                            .foregroundColor(.accentColor)
                                        Text(
                                            currentModel == .classic
                                                ? "Classic" : "Slim"
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            // Cape preview with info (if available)
                            if let capeURL = publicSkinInfo?.capeURL {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.1))
                                            .frame(width: 72, height: 96)
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: 8
                                                )
                                                .stroke(
                                                    Color.purple.opacity(0.3),
                                                    lineWidth: 1
                                                )
                                            )
                                        RemoteRawCapeImage(urlString: capeURL)
                                            .frame(width: 64, height: 88)
                                            .clipped()
                                            .shadow(radius: 1)
                                    }

                                    VStack(spacing: 2) {
                                        Text("Cape")
                                            .font(.caption.bold())
                                            .foregroundColor(.primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: "cape.fill")
                                                .font(.caption2)
                                                .foregroundColor(.purple)
                                            Text("Active")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.08))
                                            .frame(width: 72, height: 96)
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: 8
                                                )
                                                .stroke(
                                                    Color.gray.opacity(0.2),
                                                    style: StrokeStyle(
                                                        lineWidth: 1,
                                                        dash: [4, 4]
                                                    )
                                                )
                                            )
                                        VStack(spacing: 4) {
                                            Image(systemName: "cape")
                                                .font(.title3)
                                                .foregroundColor(
                                                    .gray.opacity(0.6)
                                                )
                                            Text("No Cape")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    VStack(spacing: 2) {
                                        Text("Cape")
                                            .font(.caption.bold())
                                            .foregroundColor(.primary)

                                        HStack(spacing: 4) {
                                            Image(systemName: "minus.circle")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                            Text("None")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        // Additional status information
                        if loadingPublicSkin {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading skin information...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let info = publicSkinInfo {
                            HStack(spacing: 12) {
                                // Skin status
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("Skin Loaded")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                // Cape status
                                if info.capeURL != nil {
                                    HStack(spacing: 4) {
                                        Image(
                                            systemName: "checkmark.circle.fill"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                        Text("Cape Available")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "skin.manager.no_player".localized(),
                        systemImage: "person",
                        description: Text(
                            "skin.manager.add_player_first".localized()
                        )
                    )
                }
            }
            HStack {
                Button("skin.manager.reset".localized()) {
                    guard let player = resolvedPlayer, !uploadInProgress else {
                        return
                    }
                    uploadInProgress = true
                    Task {
                        let ok = await PlayerSkinService.resetSkin(
                            player: player
                        )
                        await MainActor.run {
                            uploadInProgress = false
                            if ok {
                                Task {
                                    await loadPublicSkin(force: true)
                                    await loadPlayerProfile()
                                }
                            }
                        }
                    }
                }
                .disabled(resolvedPlayer == nil)
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
                    ContentUnavailableView(
                        "skin.manager.no_player".localized(),
                        systemImage: "person",
                        description: Text("")
                    )
                } else {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    Color.accentColor.opacity(0.4),
                                    style: StrokeStyle(
                                        lineWidth: 1,
                                        dash: [4, 4]
                                    )
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 6).fill(
                                        Color.black.opacity(0.08)
                                    )
                                )
                                .frame(width: 120, height: 120)
                            if loadingPublicSkin {
                                ProgressView().controlSize(.small)
                            } else if let info = publicSkinInfo,
                                let url = info.skinURL
                            {
                                RemoteRawSkinImage(urlString: url)
                                    .frame(width: 110, height: 110)
                                    .clipped()
                                    .shadow(radius: 1)
                            } else if let error = publicSkinError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(4)
                            } else {
                                Text(
                                    "skin.manager.preview.placeholder"
                                        .localized()
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 8) {
                            if let info = publicSkinInfo {
                                Text(
                                    info.model == .classic ? "Classic" : "Slim"
                                )
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            Button {
                                Task { await loadPublicSkin(force: true) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.plain).help(
                                "skin.manager.preview.refresh".localized()
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: resolvedPlayer?.id) { _, _ in
            Task { await loadPublicSkin(force: true) }
        }
        .task { await loadPublicSkin() }
    }

    private func loadPublicSkin(force: Bool = false) async {
        guard let player = resolvedPlayer else { return }
        if loadingPublicSkin { return }  // Avoid duplicate
        if publicSkinInfo != nil && !force { return }  // Already loaded and not forced refresh
        loadingPublicSkin = true
        publicSkinError = nil
        let info = await PlayerSkinService.fetchPublicSkin(uuid: player.id)
        await MainActor.run {
            self.publicSkinInfo = info
            self.loadingPublicSkin = false
            if info == nil {
                self.publicSkinError = "skin.manager.preview.load_failed"
                    .localized()
            }
            if let model = info?.model {
                self.currentModel = (model == .classic ? .classic : .slim)
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
                    .stroke(
                        currentModel == model
                            ? Color.accentColor : Color.gray.opacity(0.4),
                        lineWidth: currentModel == model ? 2 : 1
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                currentModel == model
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
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
                                        RoundedRectangle(cornerRadius: 2).fill(
                                            Color.gray.opacity(0.4)
                                        )
                                        .frame(width: bodyW, height: bodyH)
                                        HStack(spacing: 4) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.gray.opacity(0.4))
                                                .frame(
                                                    width: armW,
                                                    height: bodyH * 0.9
                                                )
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color.gray.opacity(0.4))
                                                .frame(
                                                    width: armW,
                                                    height: bodyH * 0.9
                                                )
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

    // MARK: - Cape Section
    private var capeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("skin.manager.section.cape".localized())

            if resolvedPlayer?.isOnlineAccount != true {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Text("skin.manager.cape.offline_not_supported".localized())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if loadingProfile {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    ProgressView("skin.manager.cape.loading".localized())
                        .controlSize(.small)
                }
            } else if let profile = playerProfile {
                capeManagementView(profile: profile)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    VStack(spacing: 8) {
                        Text("skin.manager.cape.load_failed".localized())
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button("skin.manager.cape.retry".localized()) {
                            Task { await loadPlayerProfile() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .onChange(of: resolvedPlayer?.id) { _, _ in
            Task { await loadPlayerProfile() }
        }
        .task { await loadPlayerProfile() }
    }

    private func capeManagementView(profile: MinecraftProfileResponse)
        -> some View
    {
        VStack(alignment: .leading, spacing: 16) {
            if let capes = profile.capes, !capes.isEmpty {
                // Available capes grid
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 16),
                        count: 3
                    ),
                    spacing: 16
                ) {
                    // Empty cape option (No Cape)
                    emptyCapeCard()

                    ForEach(capes, id: \.id) { cape in
                        capeCard(cape: cape)
                    }
                }
                .padding(.horizontal, 4)
            } else {
                // No capes available
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Text("skin.manager.cape.no_capes".localized())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func capeCard(cape: Cape) -> some View {
        let isActive = cape.state == "ACTIVE"

        return Button {
            if !isActive {
                Task { await equipCape(cape.id) }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isActive
                                        ? Color.accentColor
                                        : Color.gray.opacity(0.3),
                                    lineWidth: isActive ? 2 : 1
                                )
                        )

                    RemoteRawCapeImage(urlString: cape.url)
                        .frame(width: 56, height: 56)
                        .clipped()
                        .cornerRadius(6)

                    // Current cape indicator
                    if isActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(Color.accentColor, in: Circle())
                            }
                            Spacer()
                        }
                        .padding(6)
                    }
                }

                VStack(spacing: 2) {
                    Text(cape.alias ?? "skin.manager.cape.unnamed".localized())
                        .font(.caption)
                        .fontWeight(isActive ? .medium : .regular)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(isActive ? .accentColor : .primary)

                    if isActive {
                        Text("skin.manager.cape.current".localized())
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .opacity(0.8)
                    }
                }
                .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isActive
                            ? Color.accentColor.opacity(0.08)
                            : Color.gray.opacity(0.03)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isActive
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.gray.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(capeOperationInProgress || isActive)
    }

    private func emptyCapeCard() -> some View {
        let isNoCapeActive = publicSkinInfo?.capeURL == nil

        return Button {
            if !isNoCapeActive {
                Task { await hideCurrentCape() }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isNoCapeActive
                                        ? Color.accentColor
                                        : Color.gray.opacity(0.5),
                                    lineWidth: 2
                                )
                                .strokeBorder(
                                    style: StrokeStyle(
                                        lineWidth: 2,
                                        dash: [5, 5]
                                    )
                                )
                        )

                    Image(
                        systemName: isNoCapeActive
                            ? "checkmark.circle" : "xmark.circle"
                    )
                    .font(.system(size: 20))
                    .foregroundColor(isNoCapeActive ? .accentColor : .gray)

                    // Current indicator for no cape
                    if isNoCapeActive {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(Color.accentColor, in: Circle())
                            }
                            Spacer()
                        }
                        .padding(6)
                    }
                }

                VStack(spacing: 2) {
                    Text("skin.manager.cape.no_cape".localized())
                        .font(.caption)
                        .fontWeight(isNoCapeActive ? .medium : .regular)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(
                            isNoCapeActive ? .accentColor : .primary
                        )

                    if isNoCapeActive {
                        Text("skin.manager.cape.current".localized())
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                            .opacity(0.8)
                    }
                }
                .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isNoCapeActive
                            ? Color.accentColor.opacity(0.08)
                            : Color.gray.opacity(0.03)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isNoCapeActive
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.gray.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(capeOperationInProgress || isNoCapeActive)
    }

    // MARK: - Cape Operations
    private func loadPlayerProfile() async {
        guard let player = resolvedPlayer, player.isOnlineAccount else {
            await MainActor.run {
                playerProfile = nil
            }
            return
        }

        if loadingProfile { return }

        await MainActor.run {
            loadingProfile = true
        }

        let profile = await PlayerSkinService.fetchPlayerProfile(player: player)
        await MainActor.run {
            playerProfile = profile
            loadingProfile = false
        }
    }

    private func equipCape(_ capeId: String) async {
        guard let player = resolvedPlayer, !capeOperationInProgress else {
            return
        }

        await MainActor.run {
            capeOperationInProgress = true
        }

        let success = await PlayerSkinService.showCape(
            capeId: capeId,
            player: player
        )

        await MainActor.run {
            capeOperationInProgress = false
            if success {
                Task {
                    await loadPublicSkin(force: true)
                    await loadPlayerProfile()
                }
            }
        }
    }

    private func hideCurrentCape() async {
        guard let player = resolvedPlayer, !capeOperationInProgress else {
            return
        }

        await MainActor.run {
            capeOperationInProgress = true
        }

        let success = await PlayerSkinService.hideCape(player: player)

        await MainActor.run {
            capeOperationInProgress = false
            if success {
                Task {
                    await loadPublicSkin(force: true)
                    await loadPlayerProfile()
                }
            }
        }
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
                            if selectedFileURL == nil {
                                showingFileImporter = true
                            } else {
                                // Start upload
                                guard let file = selectedFileURL,
                                    let player = resolvedPlayer
                                else { return }
                                uploadInProgress = true
                                Task {
                                    do {
                                        let data = try Data(contentsOf: file)
                                        let ok =
                                            await PlayerSkinService.uploadSkin(
                                                imageData: data,
                                                model: currentModel == .classic
                                                    ? .classic : .slim,
                                                player: player
                                            )
                                        await MainActor.run {
                                            uploadInProgress = false
                                            if ok {
                                                Task {
                                                    await loadPublicSkin(
                                                        force: true
                                                    )
                                                    await loadPlayerProfile()
                                                }
                                                selectedFileURL = nil
                                            }
                                        }
                                    } catch {
                                        Logger.shared.error(
                                            "Failed to read skin file: \(error.localizedDescription)"
                                        )
                                        await MainActor.run {
                                            uploadInProgress = false
                                        }
                                    }
                                }
                            }
                        } label: {
                            Text(
                                uploadInProgress
                                    ? "skin.manager.upload.uploading"
                                        .localized()
                                    : (selectedFileURL == nil
                                        ? "skin.manager.upload.select"
                                            .localized()
                                        : "skin.manager.upload.start"
                                            .localized())
                            )
                        }
                        .disabled(uploadInProgress || resolvedPlayer == nil)
                    }
                }
                Text("skin.manager.upload.note".localized())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.png]
        ) { result in
            switch result {
            case .success(let url):
                selectedFileURL = url
                Logger.shared.info("Selected skin file: \(url.path)")
            case .failure(let error):
                Logger.shared.error(
                    "Selected skin file failed: \(error.localizedDescription)"
                )
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
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image).resizable().interpolation(.none)
            } else {
                ProgressView().controlSize(.mini)
            }
        }
        .onAppear { load() }
        .onDisappear { task?.cancel() }
    }

    private func load() {
        task?.cancel()
        task = Task {
            guard let url = URL(string: urlString) else { return }
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: url
                )
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                    let ns = NSImage(data: data)
                else { return }
                await MainActor.run { self.image = ns }
                Logger.shared.debug(
                    "[RemoteRawSkinImage] Downloaded skin image bytes=\(data.count) url=\(urlString)"
                )
            } catch {
                Logger.shared.error(
                    "[RemoteRawSkinImage] Download failed url=\(urlString) error=\(error.localizedDescription)"
                )
            }
        }
    }
}

// Cape image rendering for 64x32 cape textures
private struct RemoteRawCapeImage: View {
    let urlString: String
    @State private var image: NSImage?
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
            } else {
                ProgressView().controlSize(.mini)
            }
        }
        .onAppear { load() }
        .onDisappear { task?.cancel() }
    }

    private func load() {
        task?.cancel()
        task = Task {
            // Convert HTTP to HTTPS for Minecraft texture URLs
            let httpsUrlString = urlString.replacingOccurrences(
                of: "http://",
                with: "https://"
            )
            guard let url = URL(string: httpsUrlString) else { return }
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: url
                )
                guard (response as? HTTPURLResponse)?.statusCode == 200,
                    let ns = NSImage(data: data)
                else { return }
                await MainActor.run { self.image = ns }
                Logger.shared.debug(
                    "[RemoteRawCapeImage] Downloaded cape image bytes=\(data.count) url=\(httpsUrlString)"
                )
            } catch {
                Logger.shared.error(
                    "[RemoteRawCapeImage] Download failed url=\(httpsUrlString) error=\(error.localizedDescription)"
                )
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
            let p = playerListViewModel.players.first(where: { $0.id == id })
        {
            return p
        }
        return playerListViewModel.currentPlayer
    }
}
