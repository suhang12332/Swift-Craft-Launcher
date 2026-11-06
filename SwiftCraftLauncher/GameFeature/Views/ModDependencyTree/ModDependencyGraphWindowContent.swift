//
//  ModDependencyGraphWindowContent.swift
//  GameFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Payload used by the auxiliary dependency-graph window.
struct ModDependencyGraphWindowPayload {
    let game: GameVersionInfo
}

/// Root content of the auxiliary mod dependency graph window.
struct ModDependencyGraphWindowContent: View {
    @Environment(DIContainer.self)
    private var container

    var body: some View {
        Group {
            if let payload = container.ui.windowManager.readPayload(
                for: .modDependencyGraph,
                as: ModDependencyGraphWindowPayload.self,
            ) {
                ModDependencyGraphWindowView(game: payload.game)
            }
        }
    }
}

private struct ModDependencyGraphWindowView: View {
    let game: GameVersionInfo

    @State private var viewModel = ModDependencyGraphViewModel()
    @State private var isSaving = false

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle, .loading:
                loadingView
            case let .ready(layout):
                graphView(layout)
            case let .failed(message):
                errorView(message)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: game.id) {
            await viewModel.load(game: game)
        }
        .onDisappear {
            viewModel.clear()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await viewModel.load(game: game, force: true) }
                } label: {
                    Label("mod.dependency_graph.reload".localized(), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }

            ToolbarItem {
                Button {
                    saveImage()
                } label: {
                    Label("common.save".localized(), systemImage: "photo.badge.arrow.down")
                }
                .disabled(!viewModel.isReady || isSaving)
            }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .controlSize(.small)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("mod.dependency_graph.failed.title".localized(), systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("mod.dependency_graph.reload".localized()) {
                Task { await viewModel.load(game: game, force: true) }
            }
        }
    }

    private func graphView(_ layout: ModDependencyGraphLayout) -> some View {
        ModDependencyCanvasView(
            layout: layout,
            game: game,
            projectIcons: viewModel.projectIcons,
        )
    }

    private func saveImage() {
        guard case let .ready(layout) = viewModel.phase, !isSaving else {
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(saveFileName(for: game))-mod-dependencies.png"

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        let projectIcons = viewModel.projectIcons
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }

            let gameIcon = await ModDependencyIconLoader.loadGameIcon(for: game)
            let content = ModDependencyExportView(
                layout: layout,
                game: game,
                gameIcon: gameIcon,
                projectIcons: projectIcons,
            )
            let renderer = ImageRenderer(content: content)
            let maxDimension: CGFloat = 12000
            let longestSide = max(layout.size.width, layout.size.height)
            renderer.scale = min(3, maxDimension / longestSide)

            guard let image = renderer.cgImage else {
                reportImageSaveFailure(destinationURL)
                return
            }
            guard let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil,
            ) else {
                reportImageSaveFailure(destinationURL)
                return
            }

            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else {
                reportImageSaveFailure(destinationURL)
                return
            }
        }
    }

    private func reportImageSaveFailure(_ destinationURL: URL) {
        let message = "Failed to write dependency graph PNG to \(destinationURL.path)"
        AppLog.game.error(message)
        DIContainer.shared.core.errorHandler.handle(
            GlobalError.fileSystem(
                i18nKey: "error.filesystem.image_save_failed",
                level: .popup,
                message: message,
            ),
        )
    }

    private func saveFileName(for game: GameVersionInfo) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return game.gameName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Root card showing the game and its loader information.
struct GameDependencyCard: View {
    let game: GameVersionInfo
    let icon: NSImage?

    @State private var iconRefreshTrigger = UUID()

    init(game: GameVersionInfo, icon: NSImage? = nil) {
        self.game = game
        self.icon = icon
    }

    private var loaderName: String {
        GameLoader(rawValue: game.modLoader.lowercased())?.labelName ?? game.modLoader
    }

    private var detailText: String {
        [game.gameVersion, loaderName, game.modVersion]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                DependencyIcon(
                    image: icon,
                    fallbackSymbol: "gamecontroller.fill",
                    size: 32,
                )
            } else {
                GameIconView(
                    game: game,
                    refreshTrigger: iconRefreshTrigger,
                )
                .scaleEffect(1.6)
                .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.gameName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(7)
        .frame(
            width: ModDependencyGraphLayout.gameCardSize.width,
            height: ModDependencyGraphLayout.gameCardSize.height,
            alignment: .leading,
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)),
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        }
    }
}

/// Card showing one installed (or missing) mod and its dependency metadata.
struct ModDependencyCard: View {
    let node: ModDependencyGraph.Node
    let icon: NSImage?
    var isSelected: Bool = false

    private var fileNameText: String {
        node.fileName ?? "mod.dependency_graph.not_installed".localized()
    }

    private var borderColor: Color {
        if node.isCycle {
            return .purple.opacity(0.65)
        }
        return .secondary.opacity(0.3)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            DependencyIcon(
                image: icon,
                fallbackSymbol: node.isInstalled ? "puzzlepiece.extension.fill" : "questionmark.folder",
                size: 32,
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(fileNameText)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Match the local resource list's 50% opacity for disabled mod content.
        .opacity(node.isEnabled ? 1 : 0.5)
        .padding(7)
        .frame(
            width: ModDependencyGraphLayout.nodeSize.width,
            height: ModDependencyGraphLayout.nodeSize.height,
            alignment: .leading,
        )
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)),
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : borderColor,
                    lineWidth: isSelected ? 2.2 : 1,
                )
        }
    }
}

private struct DependencyIcon: View {
    let image: NSImage?
    let fallbackSymbol: String
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor).opacity(0.2)
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: size * 0.42))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
    }
}
