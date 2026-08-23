//
//  GameHeaderListRow.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import Combine

// A list row displaying the game icon, name, version info, and cache size.
import SwiftUI

struct GameHeaderListRow: View {
    @Environment(DIContainer.self)
    private var container
    @Environment(GameRepository.self)
    private var gameRepository
    private static let iconSize: CGFloat = 80
    private static let iconPaddingRatio: CGFloat = 0.125
    private static let iconCornerRadiusRatio: CGFloat = 0.2

    let game: GameVersionInfo
    let cacheInfo: CacheInfo
    let query: String
    var onIconTap: (() -> Void)?

    @State private var refreshTrigger: UUID = .init()
    @State private var cancellable: AnyCancellable?
    @State private var showRenamePopover = false
    @State private var viewModel = GameHeaderViewModel()

    init(
        game: GameVersionInfo,
        cacheInfo: CacheInfo,
        query: String,
        onIconTap: (() -> Void)? = nil,
    ) {
        self.game = game
        self.cacheInfo = cacheInfo
        self.query = query
        self.onIconTap = onIconTap
    }

    var body: some View {
        HStack {
            gameIcon
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    viewModel.newName = game.gameName
                    showRenamePopover = true
                } label: {
                    Text(game.gameName)
                        .font(.title)
                        .bold()
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .popover(isPresented: $showRenamePopover, arrowEdge: .top) {
                            renamePopover
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 400, alignment: .leading)
                .applyPointerHandIfAvailable()

                HStack(spacing: 8) {
                    Label(game.gameVersion, systemImage: "gamecontroller.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Divider().frame(height: 14)
                    Label(
                        game.modVersion.isEmpty
                            ? game.modLoader
                            : "\(game.modLoader)-\(game.modVersion)",
                        systemImage: "puzzlepiece.extension.fill",
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    Divider().frame(height: 14)
                    Label(
                        game.lastPlayed.formatted(
                            .relative(presentation: .named),
                        ),
                        systemImage: "clock.fill",
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            HStack {
                Label("\(cacheInfo.fileCount)", systemImage: "text.document")
                Divider()
                    .frame(height: 12)
                Label(cacheInfo.formattedSize, systemImage: "externaldrive")
            }
            .foregroundStyle(.secondary)
            .font(.headline)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(
            EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 8),
        )
    }

    private var renamePopover: some View {
        @Bindable var viewModel = viewModel

        return HStack(spacing: 8) {
            TextField("game.form.name.placeholder".localized(), text: $viewModel.newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit(renameGame)
            Button("common.confirm".localized(), action: renameGame)
                .buttonStyle(.borderedProminent)
                .disabled(!canRename)
        }
        .padding()
        .frame(width: 500)
    }

    private var canRename: Bool {
        viewModel.isNameValid(newName: viewModel.newName, currentName: game.gameName)
            && !viewModel.isRenaming
            && !container.core.gameProcessManager.isGameRunningForAnyUser(gameId: game.id)
    }

    private func renameGame() {
        guard canRename else { return }
        let newName = viewModel.newName.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.isRenaming = true

        Task { @MainActor in
            defer { viewModel.isRenaming = false }
            do {
                guard !container.core.gameProcessManager.isGameRunningForAnyUser(gameId: game.id) else { return }
                try await gameRepository.renameGame(id: game.id, to: newName)
                showRenamePopover = false
                container.ui.iconRefreshNotifier.notifyRefresh(for: nil)
            } catch {
                container.core.errorHandler.handle(GlobalError.from(error))
            }
        }
    }

    /// The URL of the icon file in the game profile directory.
    private var iconFileURL: URL? {
        let trimmed = game.gameIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = profileDir.appendingPathComponent(trimmed)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else { return nil }
        return url
    }

    /// A cache-busting URL that appends a refresh query parameter.
    private var iconDisplayURL: URL? {
        guard let baseURL = iconFileURL else { return nil }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "refresh", value: refreshTrigger.uuidString)]
        return components?.url ?? baseURL
    }

    private var gameIcon: some View {
        Group {
            if let iconURL = iconDisplayURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: Self.iconSize, height: Self.iconSize)
                    case let .success(image):
                        styledIcon(image, size: Self.iconSize)
                    case .failure:
                        defaultIcon
                    @unknown default:
                        defaultIcon
                    }
                }
                .id(refreshTrigger)
                .onDisappear {
                    URLCache.shared.removeCachedResponse(
                        for: URLRequest(url: iconURL),
                    )
                }
            } else {
                defaultIcon
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onIconTap?()
        }
        .onAppear {
            cancellable = container.ui.iconRefreshNotifier.refreshPublisher
                .sink { refreshedGameName in
                    if refreshedGameName == nil || refreshedGameName == game.gameName {
                        refreshTrigger = UUID()
                    }
                }
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .applyPointerHandIfAvailable()
    }

    private var profileDir: URL {
        AppPaths.profileDirectory(gameName: game.gameName)
    }

    private var defaultIcon: some View {
        let padding = Self.iconSize * Self.iconPaddingRatio
        let innerSize = Self.iconSize - padding * 2
        let innerCornerRadius = innerSize * Self.iconCornerRadiusRatio
        let outerCornerRadius = Self.iconSize * Self.iconCornerRadiusRatio

        return RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .overlay {
                Image(systemName: "photo.badge.plus")
                    .symbolRenderingMode(.multicolor)
                    .symbolVariant(.none)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .frame(width: innerSize, height: innerSize)
            .padding(padding)
            .frame(width: Self.iconSize, height: Self.iconSize)
            .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private func styledIcon(_ image: Image, size: CGFloat) -> some View {
        let padding = size * Self.iconPaddingRatio
        let innerSize = size - padding * 2
        let innerCornerRadius = innerSize * Self.iconCornerRadiusRatio
        let outerCornerRadius = size * Self.iconCornerRadiusRatio

        image
            .resizable()
            .interpolation(.none)
            .scaledToFill()
            .frame(width: innerSize, height: innerSize)
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
            .padding(padding)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }
}
