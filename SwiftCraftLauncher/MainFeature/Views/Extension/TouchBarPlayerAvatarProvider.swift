//
//  TouchBarPlayerAvatarProvider.swift
//  MainFeature
//
//  © 2025-2026 Swift Craft Launcher Team. All rights reserved.
//

import AppKit
import CoreImage
import Observation

/// Loads and caches the current player's 3D head avatar for the Touch Bar,
/// using the same rendering pipeline as the in-app player info view.
@MainActor
@Observable
final class TouchBarPlayerAvatarProvider {
    static let shared = TouchBarPlayerAvatarProvider()

    /// The cached avatar image, or nil while loading / when unavailable.
    var image: NSImage?

    private var lastKey = ""
    private var loadTask: Task<Void, Never>?

    private init() { }

    /// Starts or refreshes the avatar load when the player changes.
    /// Cheap to call on every Touch Bar refresh: it no-ops unless the
    /// player or avatar source changed.
    func sync(player: Player?) {
        let key = player.map { "\($0.id)|\($0.avatarName)" } ?? ""
        guard key != lastKey else { return }
        lastKey = key
        loadTask?.cancel()
        image = nil
        guard let player else { return }

        loadTask = Task { @MainActor in
            guard let loaded = await Self.loadImage(for: player), !Task.isCancelled else { return }
            image = loaded
        }
    }

    private static let touchBarImageSize: CGFloat = 28

    private static func loadImage(for player: Player) async -> NSImage? {
        let type: SkinType = player.isRemote ? .url : .asset
        let key = "touchbar:\(player.id)"
        let size = NSSize(width: touchBarImageSize, height: touchBarImageSize)

        if let cached = MinecraftSkinUtils.getCachedRenderedImage(for: key) {
            return NSImage(cgImage: cached.headImage, size: size)
        }

        do {
            let skinUtils = MinecraftSkinUtils(type: type, src: player.avatarName, size: touchBarImageSize)
            let data = try await skinUtils.loadData()
            guard let ciImage = CIImage(data: data),
                  ciImage.extent.width == 64,
                  ciImage.extent.height == 64 else {
                return nil
            }
            let rendered = await MinecraftSkinUtils.renderAndCacheImage(
                ciImage,
                for: key,
                context: MinecraftSkinUtils.ciContext,
            )
            guard let rendered else { return nil }
            return NSImage(cgImage: rendered.headImage, size: size)
        } catch {
            AppLog.player.debug("Touch Bar avatar loading failed for \(player.name): \(error.localizedDescription)")
            return nil
        }
    }
}
